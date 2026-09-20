extends Control

@export var scry_url: String = "glooplab.live:3000"
@export var show_dev_tools: bool = true
var next_event_object_for_server : Dictionary 
var outgoing_queue : Array
var full_url = ""
var headers = ["Content-Type: application/json"]
var adminDeets : Dictionary
var teamCount : int #Used for local checks to prevent you from writing to teams that dont exist
var joinCodes: Array[String]
var http_oopsie_count : int = 0 # Counts how many times the HTTP stuff has a lil sneeze 
var scoreBoard : Dictionary # local copy of scoreboard
var eventNum : int = 0 
var scoreboardNum : int = 0
var timeLimit : int = 45 
var timeRemaining : int = 0

signal got_answers(answers:Dictionary)
signal game_started(joinCodes:Array)
signal game_stopped()
signal new_event_sent(eventNum:int)
signal event_started(eventNum:int)
signal event_stopped()
signal http_issue_encountered(issue:String)
signal scoreboard_updated(scoreboardNum:int)
signal timer_ticked(secondsLeft:int)
signal timer_safely_ended()
signal timer_safely_started()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if show_dev_tools == false:
		visible = false
		print("ScryMirror Plugin Active, Dev Tools Hidden.")
	else:
		print("ScryMirror Plugin Active.")
	var adminDeetsText = FileAccess.get_file_as_string("res://adminDeets.json")
	adminDeets = JSON.parse_string(adminDeetsText)
	#game_runner_data_to_send.merge(adminDeets) #merge command combines two dictionaries
	full_url = "http://" + scry_url + "/scryGameControl/gameControllerCommand/"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#The basic loop here:
# 1. The "usual" functions (send_update, etc) maninpulate the data, and push it into the queue when appropriate
# 2. send_next_queued_to_server gets called
# 3. depending on the outgoing data, it plugs the end result of the http signal into the appropriate function
# 4. that function does something with the results, and maybe sends a signal out for the suer's project to chew on

func send_next_queued_to_server() -> void:
	if $HTTPRequest.get_http_client_status() == 1: #Bail if busy, in case functions spam this. (It should re-queue itself anyway)
		push_warning("Send Next Queued was called while HTTP was busy.")
		return
	if outgoing_queue.is_empty():
		print("Outgoing queue is empty.")
		return
	if $HTTPRequest.request_completed.is_connected(_on_startgame_request_completed): #Disconnect all. There must be a better way to do this lol
		$HTTPRequest.request_completed.disconnect(_on_startgame_request_completed)
	if $HTTPRequest.request_completed.is_connected(_on_stopgame_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_stopgame_request_completed)
	if $HTTPRequest.request_completed.is_connected(_on_getanswers_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_getanswers_request_completed)
	if $HTTPRequest.request_completed.is_connected(_on_newevent_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_newevent_request_completed)
	if $HTTPRequest.request_completed.is_connected(_on_startevent_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_startevent_request_completed)
	if $HTTPRequest.request_completed.is_connected(_on_stopevent_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_stopevent_request_completed) 
	if $HTTPRequest.request_completed.is_connected(_on_setscoreboard_request_completed):
		$HTTPRequest.request_completed.disconnect(_on_setscoreboard_request_completed) 
	if outgoing_queue[0].command == "startGame": #connects end of HTTP request to function which'll match what it was doing
		$HTTPRequest.request_completed.connect(_on_startgame_request_completed)
	if outgoing_queue[0].command == "stopGame":
		$HTTPRequest.request_completed.connect(_on_stopgame_request_completed)
	if outgoing_queue[0].command == "getAnswers":
		$HTTPRequest.request_completed.connect(_on_getanswers_request_completed)
	if outgoing_queue[0].command == "newEvent":
		$HTTPRequest.request_completed.connect(_on_newevent_request_completed)
	if outgoing_queue[0].command == "startEvent":
		$HTTPRequest.request_completed.connect(_on_startevent_request_completed)
	if outgoing_queue[0].command == "stopEvent":
		$HTTPRequest.request_completed.connect(_on_stopevent_request_completed)
	if outgoing_queue[0].command == "setScores":
		$HTTPRequest.request_completed.connect(_on_setscoreboard_request_completed)
	var json = JSON.stringify(outgoing_queue[0])
	ScryMirror.title = "ScryMirror ✨Running✨"
	$HTTPRequest.request(full_url,headers,HTTPClient.METHOD_POST,json)
	
	

func _on_request_completed(result, response_code, headers, body): #Use me as the bassis for other HTTP Nodes
	pass

func _on_startgame_request_completed(result, response_code, headers, body): #Use me as the bassis for other HTTP Nodes
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front() #Removes from queue.
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON) #just to see, should remove 
	var newJoinCodes:Array[String]
	newJoinCodes.push_front(responseJSON.joinCode) # Set up array for new joincodes
	if responseJSON.has("teams"): #If there's teams, Put their joincodes in the array
		for t in responseJSON.teams:
			if str(t) == "joinMode":
				print("skipping loop")
				continue
			print("looping normal")
			newJoinCodes.push_back(newJoinCodes[0] + "-" + str(responseJSON.teams[t].joinCode))
	print(newJoinCodes)
	game_started.emit(newJoinCodes)
	joinCodes = newJoinCodes
	scoreBoard.g = {} #Setup blank scoreboard
	var t = 1 #iterate over teamCount to make blank 
	while t <= teamCount:
		scoreBoard[str(t)] = {}
		t=t+1
	$VBoxContainer/CodesTextEdit.text = str(joinCodes)
	#print(scoreBoard)
	send_next_queued_to_server() 

func _on_stopgame_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON)
	game_stopped.emit()
	joinCodes.clear()
	scoreBoard = {}
	$VBoxContainer/CodesTextEdit.text = ""
	send_next_queued_to_server()

func _on_newevent_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON)
	eventNum = int(responseJSON.eventNum)
	new_event_sent.emit(eventNum)
	send_next_queued_to_server()

func _on_startevent_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	print("hey it sent yay!")
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON)
	event_started.emit(eventNum)
	$PreFlightTimer.start(7)
	send_next_queued_to_server()

func _on_stopevent_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON)
	next_event_object_for_server = {} #Clears this object for future go-around.
	event_stopped.emit()
	send_next_queued_to_server()

func _on_getanswers_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	got_answers.emit(responseJSON)
	send_next_queued_to_server()

func _on_setscoreboard_request_completed(result, response_code, headers, body): 
	if check_for_http_errors(result, response_code, headers, body) == true: 
		return
	outgoing_queue.pop_front()
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	print(responseJSON)
	scoreboard_updated.emit(int(responseJSON.scoreBoardNum))
	scoreboardNum = int(responseJSON.scoreBoardNum)
	send_next_queued_to_server()

func check_for_http_errors(result, response_code, headers, body)->bool:
	ScryMirror.title = "ScryMirror"
	if http_oopsie_count > 1: #Bail for real if http errors are too high
		push_error("HTTP Error Retry Count exceeded, stopping.")
		outgoing_queue.pop_front()
		return true
	if response_code != 200: #If http error, retry and tell requesting process to bail, add to http oops count
		http_oopsie_count=http_oopsie_count+1
		http_issue_encountered.emit("HTTP Error Encountered:"+str(response_code))
		push_warning("HTTP Error Encountered:"+str(response_code))
		send_next_queued_to_server()
		return true
	var responseJSON = JSON.parse_string(body.get_string_from_utf8())
	if responseJSON.has("error"):
		if responseJSON.error == true: #If server error, retry and tell requesting process to bail, add to http oops count
			http_oopsie_count = 0 
			http_issue_encountered.emit("Server Reported Issue:"+str(responseJSON.msg))
			push_warning("Server Reported Issue:"+str(responseJSON.msg))
			outgoing_queue.pop_front()
			return true
	http_oopsie_count = 0 #if no error, set http errors back to zero 
	return false



func start_game( teamSize: int) -> void:
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data.command = "startGame"
	new_data.teamCount = teamSize
	new_data.joinMode = "uniqueCodes"
	outgoing_queue.push_back(new_data)
	teamCount = teamSize # This is the local one just to prevent nonsense later
	send_next_queued_to_server()

func end_game() -> void:
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data.command = "stopGame"
	outgoing_queue.push_back(new_data)
	send_next_queued_to_server()


func set_multichoice_question(questionText:String, targetTeam:String = "ALL"):
	if next_event_object_for_server.has("questionText") or next_event_object_for_server.has("questionNameArray"):
		push_warning("There's already data queue'd up to go to the server. Are you sure you're not writing more than once?")
	next_event_object_for_server.verb = "Chose" #We're not using this much atm don't worry about it
	next_event_object_for_server.type = "multiChoice"
	if targetTeam != "ALL" : #Code for if they manually specified teams
		if targetTeam.contains(str(teamCount+1)): #Safety check if you're trying to write to a team that doesn't exist. Not perfect.
			push_error("Trying to write to a team that doesn't exist.")
			return
		next_event_object_for_server.isForTeams = targetTeam
	if targetTeam == "all" or targetTeam == "ALL" : #Iterates over teamcount and builds the string to send the Q to everyone
		var outGoingTeamString = "G"
		var i=1
		while i <= teamCount :
			outGoingTeamString = outGoingTeamString + str(i)
			i=i+1
		print(outGoingTeamString)
		next_event_object_for_server.isForTeams = outGoingTeamString
	next_event_object_for_server.questionText = questionText
	print(next_event_object_for_server)


func set_multichoice_answers(answers:Array):
	if next_event_object_for_server.has("type"):
		if next_event_object_for_server.type != "multiChoice":
			push_warning("It looks like you already have a different type of event set up.")
	var options : Array
	var i=0
	for a in answers:
		var newFella = {
			"value": str(i+1), #Automatically makes "1" "2" "3" etc the values. You could change this if you want
			"label": str(a)
		}
		i=i+1
		options.push_back(newFella)
	next_event_object_for_server.options = options
	print(next_event_object_for_server)

func set_multimulti_question(questionNameArray:Array, targetTeam:String = "ALL"):
	if next_event_object_for_server.has("questionText") or next_event_object_for_server.has("questionNameArray"):
		push_warning("There's already data queue'd up to go to the server. Are you sure you're not writing more than once?")
	next_event_object_for_server.verb = "Chose" #We're not using this much atm don't worry about it
	next_event_object_for_server.type = "multiMulti"
	if targetTeam != "ALL" : #Code for if they manually specified teams
		if targetTeam.contains(str(teamCount+1)): #Safety check if you're trying to write to a team that doesn't exist. Not perfect.
			push_error("Trying to write to a team that doesn't exist.")
			return
		next_event_object_for_server.isForTeams = targetTeam
	if targetTeam == "all" or targetTeam == "ALL" : #Iterates over teamcount and builds the string to send the Q to everyone
		var outGoingTeamString = "G"
		var i=1
		while i <= teamCount :
			outGoingTeamString = outGoingTeamString + str(i)
			i=i+1
		print(outGoingTeamString)
		next_event_object_for_server.isForTeams = outGoingTeamString
	var newOptions : Dictionary #makes a blank dictionary for the sub-objects to go in
	next_event_object_for_server.options = newOptions 
	next_event_object_for_server.options.questionNameArray = questionNameArray
	var choiceArrays : Array
	next_event_object_for_server.options.choiceArrays = choiceArrays #sets up where the answers will go
	print(next_event_object_for_server)

func append_multimulti_answers(answers:Array):
	if next_event_object_for_server.has("type"):
		if next_event_object_for_server.type != "multiMulti":
			push_warning("It looks like you already have a different type of event set up.")
	var options : Array
	var i=0
	for a in answers:
		var newFella = {
			"value": str(i+1), #Automatically makes "1" "2" "3" etc the values. You could change this if you want
			"label": str(a)
		}
		i=i+1
		options.push_back(newFella)
	var choiceArraysToUpdate = next_event_object_for_server.options.choiceArrays
	choiceArraysToUpdate.push_back(options)
	next_event_object_for_server.options.choiceArrays = choiceArraysToUpdate
	print(next_event_object_for_server)


func send_next_event() -> int:
	if not next_event_object_for_server.has("type"): #Check for a question
		push_error("Can't send event: Doesn't have a type of question.")
		return 1
	if next_event_object_for_server.has("options") or next_event_object_for_server.has("choiceArrays"): #check for answers of some kind
		var new_data : Dictionary
		new_data.merge(adminDeets)
		new_data.command = "newEvent"
		new_data.object = next_event_object_for_server
		new_data.object["timeLimit"] = timeLimit
		outgoing_queue.push_back(new_data)
		send_next_queued_to_server()
		return 0 
	else: 
		push_error("Can't send event: Looks like it's missing answers.")
		return 1

func start_event():
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data.command = "startEvent"
	outgoing_queue.push_back(new_data)
	send_next_queued_to_server()

func stop_event():
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data.command = "stopEvent"
	outgoing_queue.push_back(new_data)
	send_next_queued_to_server()


func get_answers() -> void:
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data.command = "getAnswers"
	outgoing_queue.push_back(new_data)
	send_next_queued_to_server()

func list_who_answered_this(answersDict: Dictionary, correctVal:String, teamString:String="ALL",returnNames:bool=false)-> Array: #use this function for multichoice and shorttext
	var responseArray = []
	var players = answersDict.players # get a copy of the players dictionary, specifically
	for i in players: # iterate over each item
		if players[i].has("teamNumber"): # check for presence of teamNumber value
			if str(players[i].teamNumber) in teamString or teamString == "ALL": # yes teamnumber? check if matches any value in teamstring OR auto-yes on all
				if str(players[i].answer.value) == str(correctVal): # if yes to above, check if matches correctVal
					if returnNames == true: #if yes to THAT, check if returnNames. Append name if so otherwise append playerID
						responseArray.push_back(str(players[i].name))
					else:
						responseArray.push_back(i)
		else: # no teamnumber logic. 
			if "g" in teamString or "G" in teamString or teamString == "ALL": # check if g for general or all is present above
				if str(players[i].answer.value) == str(correctVal): # if so, check if matches correctVal
					if returnNames == true: #if yes to THAT, check if returnNames. Append name if so otherwise append playerID
						responseArray.push_back(str(players[i].name))
					else:
						responseArray.push_back(i)
	return responseArray

func list_who_answered_this_multimulti(answersDict: Dictionary, correctPos:int, correctVal:String, teamString:String="ALL",returnNames:bool=false)-> Array: #Accounts for multimulti returning an array
	var responseArray = []
	var players = answersDict.players # get a copy of the players dictionary, specifically
	for i in players: # iterate over each item
		if players[i].has("teamNumber"): # check for presence of teamNumber value
			if str(players[i].teamNumber) in teamString or teamString == "ALL": # yes teamnumber? check if matches any value in teamstring OR auto-yes on all
				if str(players[i].answer.value[correctPos]) == str(correctVal): # if yes to above, check if matches correctVal
					if returnNames == true: #if yes to THAT, check if returnNames. Append name if so otherwise append playerID
						responseArray.push_back(str(players[i].name))
					else:
						responseArray.push_back(i)
		else: # no teamnumber logic. 
			if "g" in teamString or "G" in teamString or teamString == "ALL": # check if g for general or all is present above
				if str(players[i].answer.value[correctPos]) == str(correctVal): # if so, check if matches correctVal
					if returnNames == true: #if yes to THAT, check if returnNames. Append name if so otherwise append playerID
						responseArray.push_back(str(players[i].name))
					else:
						responseArray.push_back(i)
	return responseArray

func scoreboard_send_update()-> void:
	var new_data : Dictionary
	new_data.merge(adminDeets)
	new_data["object"] = scoreBoard
	new_data.command = "setScores"
	outgoing_queue.push_back(new_data)
	send_next_queued_to_server()

func scoreboard_create_item(teamTargets:String, name:String,label:String, value:String, row:int,column:int,width:int,height:int) -> void:
	if teamTargets == "ALL": #If it's an ALL, iterate over every item in the scoreboard and create an object
		for i in scoreBoard:
			print("running all loop on" + str(i))
			scoreBoard[i][name] = { #I didn't know you could double-stack these. Crazy.
				"label": label,
				"value": value,
				"row": row,
				"column":column,
				"width":width,
				"height":height
			}
			print(scoreBoard[i][name])
	else:
		teamTargets.replace("G","g") #lil' typo you know how it do
		for t in teamTargets: #Iterate over each letter in the team targets list and create an object accordingly.
			if scoreBoard.has(t):
				scoreBoard[t]["name"]= {
					"label": label,
					"value": value,
					"row": row,
					"column":column,
					"width":width,
					"height":height
				}
			else:
				push_error(t +" Isn't a valid team.")
	print(scoreBoard)

func scoreboard_edit_item(name:String,value:String, teamTargets:String = "EXISTING") -> void:
	if teamTargets == "EXISTING": #If it's an EXISTING, iterate over every item in the scoreboard, check, and update if it exists.
		print("Running existing behavior.")
		for i in scoreBoard:
			print("running all loop on" + str(i)) 
			if scoreBoard[i].has(name):
				scoreBoard[i][name].value = value
				print("updated value on " + str(i))
	else:
		teamTargets.replace("G","g") #lil' typo you know how it do
		print("running team specific behavior")
		for t in teamTargets: #Check for existence of (name) in each scoreBoard item on the team list, and update.
			if scoreBoard.has(t):
				if scoreBoard[t].has(name):
					scoreBoard[t][name].value = value
					print("updated value on " + str(t))
			else:
				push_error(t +" Isn't a valid team.")
	print(scoreBoard)

func scoreboard_delete_item(name:String,teamTargets:String = "EXISTING") -> void:
	if teamTargets == "EXISTING": #If it's an EXISTING, iterate over every item in the scoreboard, check, and update if it exists.
		print("Running existing behavior.")
		for i in scoreBoard:
			print("Running all loop on " + str(i)) 
			if scoreBoard[i].has(name):
				scoreBoard[i].erase(name)
				print("Deleted on" + str(i))
	else:
		teamTargets.replace("G","g") #lil' typo you know how it do
		print("running team specific behavior")
		for t in teamTargets: #Check for existence of (name) in each scoreBoard item on the team list, and update.
			if scoreBoard.has(t):
				if scoreBoard[t].has(name):
					scoreBoard[t].erase(name)
					print("Deleted on " + str(t))
			else:
				push_error(t +" Isn't a valid team.")
	print(scoreBoard)

# ~Timers~
# Timing system includes "safety" timers. Seven seconds on the front end for clients to catch up and users to get in the right place.
# 3 at the end to let the server mop up 

func set_timer(newTime:int)->void:
	if $EventTickTimer.is_stopped() == false or $FinalSafetyTimer.is_stopped() == false or $PreFlightTimer.is_stopped() == false:
		push_error("Can't update time remaining while time is running.")
	else:
		timeLimit = newTime

func _on_pre_flight_timer_timeout() -> void:
	timeRemaining = timeLimit #start the timer 
	timer_safely_started.emit()
	$EventTickTimer.start(1)

func _on_event_tick_timer_timeout() -> void:
	timeRemaining = timeRemaining - 1
	timer_ticked.emit(timeRemaining)
	if timeRemaining > 0 :
		$EventTickTimer.start(1)
	if timeRemaining == 0 :
		$FinalSafetyTimer.start()

func _on_final_safety_timer_timeout() -> void:
	timer_safely_ended.emit()



# !~Debug UI Below here Only~!
# If you're looking for a problem, stop here
# It shouldn't be us don't use us don't touch us we're not here
# When I was little my mom was like "sit on your hands" instead of "dont touch anything" because that actually got results

func _on_start_button_pressed() -> void:
	var teamSize = int($VBoxContainer/Hbox1/TeamcountSpinBox.value)
	start_game(teamSize)


func _on_end_button_pressed() -> void:
	end_game()


func _on_get_answers_button_pressed() -> void:
	ScryMirror.got_answers.connect(_on_debug_gotanswers)
	ScryMirror.get_answers()
func _on_debug_gotanswers(answers:Dictionary) -> void:
	print(answers)


func _on_send_random_q_button_pressed() -> void:
	var teamString="G"
	var i = 1
	var teamCount = int($VBoxContainer/Hbox1/TeamcountSpinBox.value)
	#print(teamCount)
	while i <= teamCount: #make the teamString as long as the number of teams that exist
		teamString = teamString + str(i)
		#print("toot")
		print(i)
		i=i+1
	#print ("beep")
	var questionString = "Random Question, " + str(randi() % 500) #generate some random stuff
	ScryMirror.set_multichoice_question(questionString,teamString)


func _on_send_random_as_button_pressed() -> void:
	var newAnswersArray : Array
	var i=0
	while i < 5:
		newAnswersArray.push_back("Random A " + str(randi() % 500))
		i=i+1
	ScryMirror.set_multichoice_answers(newAnswersArray)

func _on_send_multi_multi_qs_button_pressed() -> void:
	var teamString="G"
	var i = 1
	var teamCount = int($VBoxContainer/Hbox1/TeamcountSpinBox.value)
	#print(teamCount)
	while i <= teamCount: #make the teamString as long as the number of teams that exist
		teamString = teamString + str(i)
		#print("toot")
		print(i)
		i=i+1
	#print ("beep")
	var questionArray = ["What is a frog?","How many puppies are there?","Is this the third question?"]
	ScryMirror.set_multimulti_question(questionArray,teamString)

func _on_send_multi_multi_as_button_pressed() -> void:
	var answer1Array = ["A nice friend","A tiny man","A good soup"]
	var answer2Array = ["One dog","101, we had a movie about this","Billions","Dogs aren't real"]
	var answer3Array = ["Yes","No","It is 'many' questions because we have a primitive counting structure"]
	ScryMirror.append_multimulti_answers(answer1Array)
	ScryMirror.append_multimulti_answers(answer2Array)
	ScryMirror.append_multimulti_answers(answer3Array)



func _on_send_event_button_pressed() -> void:
	send_next_event()


func _on_start_event_button_pressed() -> void:
	ScryMirror.start_event()


func _on_end_event_button_pressed() -> void:
	ScryMirror.stop_event()


func _on_scoreboard_create_button_pressed() -> void:
	var name = $"VBoxContainer/HBoxContainer2/TabContainer/ScoreBoard Values/NameLineEdit".text
	var label = $"VBoxContainer/HBoxContainer2/TabContainer/ScoreBoard Values/LabelLineEdit".text
	var value = $"VBoxContainer/HBoxContainer2/TabContainer/ScoreBoard Values/ValueLineEdit".text
	var row = int($"VBoxContainer/HBoxContainer2/TabContainer/Pose & Create/ScoreBox Pos/RowSpinBox".value)
	var col = int($"VBoxContainer/HBoxContainer2/TabContainer/Pose & Create/ScoreBox Pos/ColSpinBox".value)
	var width = int($"VBoxContainer/HBoxContainer2/TabContainer/Pose & Create/HBoxContainer/WidthSpinBox".value)
	var height = int($"VBoxContainer/HBoxContainer2/TabContainer/Pose & Create/HBoxContainer/HeightSpinBox".value)
	scoreboard_create_item("ALL",name,label,value,row,col,width,height) ##NAUGHTY NAUGHTY NAUGHTY DELETE ME IM FOR TESTING
	#scoreboard_create_item("ALL","dog","label","value",1,1,1,1) ##NAUGHTY NAUGHTY NAUGHTY DELETE ME IM FOR TESTING
	scoreboard_send_update()
	pass # Replace with function body.


func _on_score_edit_button_pressed() -> void:
	var name = $"VBoxContainer/HBoxContainer2/TabContainer/ScoreBoard Values/NameLineEdit".text
	var newValue = $"VBoxContainer/HBoxContainer2/TabContainer/Edit & Del/ScoreEditLineEdit".text
	scoreboard_edit_item(name, newValue)
	scoreboard_send_update()


func _on_scoreboard_delete_button_pressed() -> void:
	var name = $"VBoxContainer/HBoxContainer2/TabContainer/ScoreBoard Values/NameLineEdit".text
	scoreboard_delete_item(name)
	scoreboard_send_update()
