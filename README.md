This plugin is designed to make it easier for a Godot project to work with ScryMirror.

### Full Setup And ScryMirror Info Here:
https://github.com/GloopQueen/scrymirror-server/wiki/ScryMirror-101:-Home

### Quick and Dirty Setup Steps:
1. Start a Godot project (I was using Godot 4.7.1)
2. Make sure all this stuff is in res://addons/scrymirror_plugin
3. Open your Project Settings, go to plugins, and make sure "ScryMirror for Godot Plugin" is checked.
4. Make sure you have an 'adminDeets.json' in the project's root folder with your login info for ScryMirror. (Ask Gloop!)

You should be set up. Open up 'scrymirror.tscn' and check the inspector: There should be a field to set the URL, and a "Show Dev Tools" checkbox.

*Scry URL* - This should be 'glooplab.live/api/' to talk to the "real" ScryMirror that the whole internet can see.

*Show Dev Tools* - There's a little gizmo which will let you instance ScryMirror games, send some test questions, update the scoreboard, things like that. **This thing will show Join Codes**, so if you're streaming and don't want to share those, you may want to collapse it or switch it off entirely.
