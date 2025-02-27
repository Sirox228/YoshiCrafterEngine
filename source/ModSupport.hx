import haxe.crypto.Md5;
import Medals.MedalsJSON;
import haxe.Exception;
import flixel.addons.display.FlxBackdrop;
#if desktop
import discord_rpc.DiscordRpc;
import Discord.DiscordClient;
#end
import openfl.display.BlendMode;
import flixel.tile.FlxTilemap;
import animateatlas.AtlasFrameMaker;
import Script.HScript;
import haxe.EnumTools;
import mod_support_stuff.ModState;
import hscript.Expr;
import openfl.utils.AssetLibrary;
import openfl.utils.AssetManifest;
import haxe.io.Path;
import haxe.io.Bytes;
import Shaders.ColorShader;
#if (desktop || android)
// (sirox) dumb, this works on android
import cpp.Lib;
#end
import flixel.util.FlxSave;
import lime.app.Application;
import haxe.PosInfos;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import flixel.util.FlxAxes;
import flixel.addons.text.FlxTypeText;
import openfl.display.PNGEncoderOptions;
import flixel.tweens.FlxEase;
import haxe.Json;
import flixel.util.FlxTimer;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.media.Sound;
import sys.FileSystem;
import haxe.display.JsonModuleTypes.JsonTypeParameters;
import flixel.addons.effects.chainable.FlxShakeEffect;
import flixel.FlxBasic;
import flixel.text.FlxText;
import flixel.FlxState;
import flixel.system.FlxSound;
import flixel.util.FlxColor;
import sys.io.File;
import lime.utils.Assets;
import openfl.utils.Assets as DeezNutsAssets;
import flixel.system.FlxAssets;
import flixel.FlxSprite;
import openfl.display.BitmapData;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.input.keyboard.FlxKey;
import mod_support_stuff.*;
import stage.Stage;

using StringTools;

#if windows
@:headerCode("#include <windows.h>")
@:headerCode("#undef RegisterClass")
#end

typedef CacheExpr = {
	var code:Expr;
	var time:Null<Float>;
}

@:allow(CoolUtil)
@:allow(Main)
class ModSupport {
    public static var song_cutscene:ModScript = null;
    public static var song_end_cutscene:ModScript = null;
    public static var currentMod:String = "Friday Night Funkin'";

    public static var scripts:Array<ModScript> = [];

    public static var modConfig:Map<String, ModConfig> = [];
    public static var modSaves:Map<String, FlxSave> = [];
    public static var modMedals:Map<String, MedalsJSON> = [];

    private static var forceDevMode:Bool = false;


    public static var mFolder = Paths.modsPath;

    public static function refreshDiscordRpc() {
        // if (!DiscordClient.init) {
        //     trace("Discord not init yet");
        //     return;
        // }
        // var discordRpc = "915896776869953588";
        // if (Settings.engineSettings == null) return;
        // var mod:ModConfig = modConfig[Settings.engineSettings.data.selectedMod];
        // if (mod == null) return;
        // if (mod.discordRpc != null) discordRpc = mod.discordRpc;
        // DiscordClient.currentButton1Label = "Download Mod";
        // DiscordClient.currentButton1Url = (mod.downloadLink == null || mod.downloadLink.trim() == "") ? null : mod.downloadLink;
        // DiscordClient.currentButton2Label = "Download Mod (Alt Link)";
        // DiscordClient.currentButton2Url = (mod.downloadLinkAlt != null && mod.downloadLinkAlt.trim() != "") ? mod.downloadLinkAlt : null;
        // DiscordClient.switchRPC(discordRpc);
        #if desktop
        if (!DiscordClient.init) {
            trace("Discord not init yet");
            return;
        }
        var discordRpc = "915896776869953588";
        var mod:ModConfig = null;
        if (Settings.engineSettings != null && ((mod = modConfig[Settings.engineSettings.data.selectedMod]) != null) && mod.discordRpc != null) {
            discordRpc = mod.discordRpc;
        }
        DiscordClient.currentButton1Label = "Download Mod";
        DiscordClient.currentButton1Url = (mod.downloadLink == null || mod.downloadLink.trim() == "") ? null : mod.downloadLink;
        DiscordClient.currentButton2Label = "Download Mod (Alt Link)";
        DiscordClient.currentButton2Url = (mod.downloadLinkAlt != null && mod.downloadLinkAlt.trim() != "") ? mod.downloadLinkAlt : null;
        
        DiscordClient.switchRPC(discordRpc);
        #end
    }
    public static function getMods():Array<String> {
        var modFolder = Paths.modsPath;
        var a = FileSystem.readDirectory(modFolder);
        var finalArray = [];
        for (e in a) {
            if (FileSystem.isDirectory('$modFolder/$e')) finalArray.push(e);
        }
        return finalArray;
    }

    public static function getAssetFiles(assets:Array<Dynamic>, rootPath:String, path:String, libraryName:String, prefix:String = "", addRoot:Bool = false) {
        for(f in FileSystem.readDirectory('$rootPath$path')) {
            if (FileSystem.isDirectory('$rootPath$path$f')) {
                // fuck you git
                if (Paths.matchPath(f, function(str:String) { return str != ".git"; }))
                    getAssetFiles(assets, rootPath, '$path$f/', libraryName);
            } else {
                var type:String = "BINARY";
                var useExt:Bool = true;
                switch(Path.extension(f).toLowerCase()) {
                    case "txt" | "xml" | "json" | "hx" | "hscript" | "hsc" | "lua" | "frag" | "vert":
                        type = "TEXT";
                    case "png":
                        type = "IMAGE";
                    case "ogg":
                        type = path.toLowerCase().startsWith("music") ? "MUSIC" : "SOUND";
                    case "ttf":
                        type = "FONT";
                        useExt = false;

                }
                var stat:sys.FileStat = FileSystem.stat('$rootPath$path$f');
                assets.push({
                    type: type,
                    id: ('assets/$libraryName/$prefix$path${useExt ? f : Path.withoutExtension(f)}').toLowerCase(), // for case sensitive shit & correct linux support
                    path: (addRoot ? rootPath : '') + '$path$f',
                    size: stat.size,
                    edited: stat.mtime.getTime() / 1000
                });
            }
        }
    }

    public static var lastTitlebarMod:String = "Friday Night Funkin'";

    public static function getModTitleBarTitle(mod:String) {
        var title = getModName(mod);

        var modConf = modConfig[mod];
		if (modConf != null && modConf.titleBarName != "" && modConf.titleBarName != null)
		{
			title = modConf.titleBarName;
		}
		else
		{
			var fullTitleThingies = ["friday night funkin", "-", "fnf"];
			var fullTitle = false;
			for (t in fullTitleThingies)
			{
				if (Paths.matchPath(mod, function(str:String) { return str.contains(t); }))
				{
					fullTitle = true;
					break;
				}
			}
			if (!fullTitle)
				title = 'Friday Night Funkin\' - $title';
		}
        return title;
    }
    public static function updateTitleBar() {
        if (Settings.engineSettings == null) return;
        var mod = Settings.engineSettings.data.selectedMod;

        if (lastTitlebarMod == mod) return;
        
		lime.app.Application.current.window.title = getModTitleBarTitle(mod);

        lastTitlebarMod = mod;

        #if windows
        var iconPath = '${Paths.modsPath}/${mod}/icon.ico';
        if (FileSystem.exists(iconPath)) {
            HeaderCompilationBypass.setWindowIcon(iconPath);
            return;
        }
        #end

        var path = Paths.getPath("icon.png", IMAGE);
        if (!Assets.exists(path)) {
            #if windows
            HeaderCompilationBypass.setWindowIcon("icon.ico");
            return;
            #else
            path = Paths.image("icon");
            #end
        }
        lime.app.Application.current.window.setIcon(lime.utils.Assets.getImage(path));
        


    }
    public static function reloadModsConfig(reloadAll:Bool = false, reloadSkins:Bool = true, clearCache:Bool = false, reloadCurrent:Bool = false):Bool {
        if (clearCache) {
            lime.app.Application.current.window.alert("clearing cache", "TRACE");
            Assets.cache.clear();
            openfl.utils.Assets.cache.clear();
            // long ass reset but you cant stop me haha
            PlayState.SONG = null;
            PlayState._SONG = null;
            PlayState.scripts = null;
            PlayState.cutscene = null;
            PlayState.end_cutscene = null;
            PlayState.prevCamFollow = null;
            PlayState.current = null;
            PlayState.actualModWeek = null;
            PlayState.startTime = 0;
            PlayState.blueballAmount = 0;
            PlayState.fromCharter = false;
            PlayState.songMod = "Friday Night Funkin'";
            lime.app.Application.current.window.alert("cleared cache", "TRACE");
        }

        if (reloadSkins) {
            // skins shit
            lime.app.Application.current.window.alert("loading skins", "TRACE");
            var assets:AssetManifest = new AssetManifest();
            assets.name = "skins";// for case sensitive shit & correct linux support
            lime.app.Application.current.window.alert("created ass library", "TRACE");
            FileSystem.createDirectory('${Paths.getSkinsPath()}/bf/');
            FileSystem.createDirectory('${Paths.getSkinsPath()}/gf/');
            FileSystem.createDirectory('${Paths.getSkinsPath()}/notes/');
            lime.app.Application.current.window.alert("created folders", "TRACE");
            for (char in ["bf", "gf"]) {
                lime.app.Application.current.window.alert("char: " + Std.string(Type.typeof(char)), "TRACE");
                var thing:Array<String> = [];
                for (e in FileSystem.readDirectory('${Paths.getSkinsPath()}${char}/')) {
                    lime.app.Application.current.window.alert("reading skin directory", "TRACE");
                    if (FileSystem.isDirectory('${Paths.getSkinsPath()}${char}/${e}')) {
                        lime.app.Application.current.window.alert("pushing skin", "TRACE");
                        thing.push(e);
                    }
                }
                lime.app.Application.current.window.alert("skins pushed", "TRACE");
                for(skin in thing) {
                    lime.app.Application.current.window.alert("skin: " + Std.string(Type.typeof(skin)), "TRACE");
                    var path:String = '${Paths.getSkinsPath()}${char}/${skin}/';
                    lime.app.Application.current.window.alert("lots of shit", "TRACE");
                    for (f in FileSystem.readDirectory(path)) {
                        var type = "TEXT";
                        if (Path.extension(f).toLowerCase() == "png") {
                            type = "IMAGE";
                        }
                        lime.app.Application.current.window.alert("pushing", "TRACE");
                        assets.assets.push({
                            type: type,
                            id: ('assets/skins/characters/$char/$skin/$f').toLowerCase(), // for case sensitive shit & correct linux support
                            path: '$path$f',
                            size: FileSystem.stat('$path$f').size
                        });
                    }
                }
            }
            try {
                Paths.voidMatchPath('${Paths.getSkinsPath()}notes/', function(hell:String) { getAssetFiles(assets.assets, hell, '', 'skins', 'images/', true); });
            } catch(e) {
                trace(e.details());
            }
            lime.app.Application.current.window.alert("registering lib", "TRACE");
            if (openfl.utils.Assets.hasLibrary("skins"))
                openfl.utils.Assets.unloadLibrary("skins");
            openfl.utils.Assets.registerLibrary("skins", AssetLibrary.fromManifest(assets));
            lime.app.Application.current.window.alert("done", "TRACE");
        }
        lime.app.Application.current.window.alert("Starting making mods", "TRACE");
        var mods:Array<String> = getMods();
        var newMod:Bool = false;
        for(mod in mods) {
            if (reloadAll || modConfig[mod] == null || (reloadCurrent && mod == Settings.engineSettings.data.selectedMod)) {
                newMod = loadMod(mod) || newMod;
            }
        }
        lime.app.Application.current.window.alert("finished mods", "TRACE");
        Settings.engineSettings.data.lastInstalledMods = mods;
        return newMod;
    }

    public static var assetEditTimes:Map<String, Float> = [];

    public static var lastCursorMod:String = null;
    public static function updateCursor() {
        if (Settings.engineSettings == null) return;
        var mod = Settings.engineSettings.data.selectedMod;
        var path = null;
        if (lastCursorMod != (lastCursorMod = mod)) {
            if (Assets.exists(path = Paths.image('cursor', 'mods/$mod')))
                FlxG.mouse.load(DeezNutsAssets.getBitmapData(path));
            else
                FlxG.mouse.unload();
        }
        
    }
    public static function getEditedTime(asset:String) {
        return assetEditTimes.exists(asset) ? assetEditTimes.get(asset) : 0;
    }

    public static function checkForOutdatedAssets(assets:AssetManifest) {
        for(e in assets.assets) {
            if (e == null) continue;
            if (Reflect.hasField(e, "id") && Reflect.hasField(e, "edited")) {
                var id = '${assets.name}:${e.id}';
                if (getEditedTime(id) < e.edited) {
                    Assets.cache.clear(id);
                    @:privateAccess
                    FlxG.bitmap.removeKey(id);
                }
                assetEditTimes[id] = e.edited;
            }
        }
    }
    public static function loadMod(mod:String) {
        lime.app.Application.current.window.alert("save", "TRACE");
        try {
            var s = new FlxSave();
            s.bind('mod_${Md5.encode(mod.toLowerCase())}');
            s.data.mod = mod;
            modSaves[mod] = s;
        } catch(e) {
            trace(e.details());
        }
        
        // imma do assets lol
        lime.app.Application.current.window.alert("creating that ass fucking library", "TRACE");
        var libName:String = 'mods/$mod';
        var assets:AssetManifest = new AssetManifest();
        assets.name = libName;// for case sensitive shit & correct linux support
        assets.rootPath = '${Paths.modsPath}/$mod/';
        Paths.voidMatchPath('${Paths.modsPath}/$mod/', function(aaaa:String) { getAssetFiles(assets.assets, aaaa, '', libName); });
        lime.app.Application.current.window.alert("checking for outdated", "TRACE");
        checkForOutdatedAssets(assets);
        lime.app.Application.current.window.alert("adding library", "TRACE");
        if (openfl.utils.Assets.hasLibrary(libName))
            openfl.utils.Assets.unloadLibrary(libName);
        openfl.utils.Assets.registerLibrary(libName, AssetLibrary.fromManifest(assets));

        lime.app.Application.current.window.alert("loading config.json", "TRACE");

        var json:ModConfig = null;
        var path = Paths.getPath('config.json', TEXT, libName);
        if (Assets.exists(path)) {
            try {
                json = Json.parse(Assets.getText(path));
            } catch(e) {
                LogsOverlay.error(e);
            }
        }
            
        if (json == null) json = {
            name: null,
            description: null,
            titleBarName: null,
            skinnableGFs: null,
            skinnableBFs: null,
            BFskins: null,
            GFskins: null,
            keyNumbers: null,
            locked: false,
            intro: {
                bpm: 102,
                authors: ['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er'],
                present: 'present',
                assoc: ['In association', 'with'],
                newgrounds: 'newgrounds',
                gameName: ['Friday Night Funkin\'', 'YoshiCrafter', 'Engine']
            }
        };
        lime.app.Application.current.window.alert("setting modConfig[mod] to json", "TRACE");
        modConfig[mod] = json;
        lime.app.Application.current.window.alert("medals shit", "TRACE");
        if (Assets.exists(Paths.file('medals.json', TEXT, 'mods/$mod'))) {
            try {
                modMedals[mod] = Json.parse(Assets.getText(Paths.file('medals.json', TEXT, 'mods/$mod')));
            } catch(e) {
                FlxG.log.error(e);
                modMedals[mod] = {medals: []};
            }
        } else {
            modMedals[mod] = {medals: []};
            File.saveContent('${Paths.modsPath}/$mod/medals.json', Json.stringify(modMedals[mod]));
        }
        lime.app.Application.current.window.alert("medals done", "TRACE");
        if (!Settings.engineSettings.data.lastInstalledMods.contains(mod)) {
            trace("NEW MOD INSTALLED: " + mod);
            if (Settings.engineSettings.data.autoSwitchToLastInstalledMod) {
                Settings.engineSettings.data.selectedMod = mod;
                lime.app.Application.current.window.alert("is working", "TRACE");
                return true;
            }
        }
        lime.app.Application.current.window.alert("is working", "TRACE");
        return false;
    }
    #if windows
    public static function changeWindowIcon(iconPath:String) {
        
    }
    #end
    public static function getExpressionFromPath(path:String, critical:Bool = false):hscript.Expr {
        var ast:Expr = null;
        try {
			var cachePath = path;
			var fileData = FileSystem.stat(path);
            var content = sys.io.File.getContent(Paths.gameFilesPath() + path);
            ast = getExpressionFromString(content, critical, path);
        } catch(ex) {
            if (!openfl.Lib.application.window.fullscreen && critical) openfl.Lib.application.window.alert('Could not read the file at "$path".');
            trace('Could not read the file at "$path".');
        }
        return ast;
    }
    public static function getExpressionFromString(code:String, critical:Bool = false, ?path:String):hscript.Expr {
        if (code == null) return null;
        var parser = new hscript.Parser();
		parser.allowTypes = true;
        var ast:Expr = null;
		try {
			ast = parser.parseString(code);
		} catch(ex) {
			trace(ex);
            var exThingy = Std.string(ex);
            var line = parser.line;
            if (path != null) {
                if (!openfl.Lib.application.window.fullscreen && critical) openfl.Lib.application.window.alert('Failed to parse the file located at "$path".\r\n$exThingy at $line');
                trace('Failed to parse the file located at "$path".\r\n$exThingy at $line');
            } else {
                if (!openfl.Lib.application.window.fullscreen && critical) openfl.Lib.application.window.alert('Failed to parse the given code.\r\n$exThingy at $line');
                trace('Failed to parse the given code.\r\n$exThingy at $line');
                if (!critical) throw new Exception('Failed to parse the given code.\r\n$exThingy at $line');
            }
		}
        return ast;
    }

    public static function hTrace(text:String, hscript:hscript.Interp) {
        var posInfo = hscript.posInfos();

        var fileName = posInfo.fileName;
        var lineNumber = Std.string(posInfo.lineNumber);
        var methodName = posInfo.methodName;
        var className = posInfo.className;
        trace('$fileName:$methodName:$lineNumber: $text');

        if (!Settings.engineSettings.data.developerMode) return;
        for (e in ('$fileName:$methodName:$lineNumber: $text').split("\n")) LogsOverlay.trace(e.trim());
    }

    public static function saveModData(mod:String):Bool {
        if (FileSystem.exists('${Paths.modsPath}/$mod/')) {
            if (modConfig[mod] != null) {
                File.saveContent('${Paths.modsPath}/$mod/config.json', Json.stringify(modConfig[mod], "\t"));
                return true;
            }
        }
        return false;
    }
    public static function getModName(mod:String):String {
        var name = mod;
        if (modConfig[mod] != null) {
            if (modConfig[mod].name != null) {
                name = modConfig[mod].name.trim();
            }
        }
        return name;
    }
    public static function setScriptDefaultVars(script:Script, mod:String, settings:Any) {
        var superVar = {};
        if (Std.isOfType(script, HScript)) {
            var hscript:HScript = cast script;
            for(k=>v in hscript.hscript.variables) {
                Reflect.setField(superVar, k, v);
            }
        }
        script.mod = mod;
		script.setVariable("this", script);
		script.setVariable("super", superVar);
		script.setVariable("mod", mod);
		script.setVariable("PlayState", PlayState.current);
        script.setVariable("import", function(className:String) {
            var splitClassName = [for (e in className.split(".")) e.trim()];
            var realClassName = splitClassName.join(".");
            var cl = Type.resolveClass(realClassName);
            var en = Type.resolveEnum(realClassName);
            if (cl == null && en == null) {
                LogsOverlay.error('Class / Enum at $realClassName does not exist.');
            } else {
                if (en != null) {
                    // ENUM!!!!
                    var enumThingy = {};
                    for(c in en.getConstructors()) {
                        Reflect.setField(enumThingy, c, en.createByName(c));
                    }
                    script.setVariable(splitClassName[splitClassName.length - 1], enumThingy);
                } else {
                    // CLASS!!!!
                    script.setVariable(splitClassName[splitClassName.length - 1], cl);
                }
            }
        });

        if (PlayState.current != null) {
            script.setVariable("EngineSettings", PlayState.current.engineSettings);
            script.setVariable("global", PlayState.current.vars);
            script.setVariable("loadStage", function(stagePath) {
                return new Stage(stagePath, mod);
            });

        } else {
            script.setVariable("EngineSettings", {});
            script.setVariable("global", {});
            script.setVariable("loadStage", function(stagePath) {
                return null;
            });
        }
        script.setVariable("trace", function(text) {
            try {
                script.trace(text);
            } catch(e) {
                trace(e);
            } 
        });
		script.setVariable("PlayState_", PlayState);
		script.setVariable("FlxSprite", FlxSprite);
		script.setVariable("BitmapData", BitmapData);
		script.setVariable("FlxBackdrop", FlxBackdrop);
		script.setVariable("FlxG", FlxG);
		script.setVariable("Paths", Paths);
		script.setVariable("Medals", new ModMedals(mod));
		script.setVariable("Paths_", Paths);
		script.setVariable("Std", Std);
		script.setVariable("Math", Math);
		script.setVariable("FlxMath", FlxMath);
		script.setVariable("FlxAssets", FlxAssets);
        script.setVariable("Assets", Assets);
		script.setVariable("ModSupport", ModSupport);
		script.setVariable("Note", Note);
		script.setVariable("Character", Character);
		script.setVariable("Conductor", Conductor);
		script.setVariable("StringTools", StringTools);
		script.setVariable("FlxSound", FlxSound);
		script.setVariable("FlxEase", FlxEase);
		script.setVariable("FlxTween", FlxTween);
		script.setVariable("FlxPoint", flixel.math.FlxPoint);
		script.setVariable("FlxColor", FlxColor_Helper);
		script.setVariable("Boyfriend", Boyfriend);
		script.setVariable("FlxTypedGroup", FlxTypedGroup);
		script.setVariable("BackgroundDancer", BackgroundDancer);
		script.setVariable("BackgroundGirls", BackgroundGirls);
		script.setVariable("FlxTimer", FlxTimer);
		script.setVariable("Json", Json);
		script.setVariable("MP4Video", MP4Video);
		script.setVariable("CoolUtil", CoolUtil);
		script.setVariable("FlxTypeText", FlxTypeText);
		script.setVariable("FlxText", FlxText);
		script.setVariable("BitmapDataPlus", BitmapDataPlus);
		script.setVariable("Rectangle", Rectangle);
		script.setVariable("Point", Point);
		script.setVariable("Window", Application.current.window);

		script.setVariable("ColorShader", Shaders.ColorShader);
		script.setVariable("BlammedShader", Shaders.BlammedShader);
		script.setVariable("GameOverSubstate", GameOverSubstate);
		script.setVariable("ModSupport", null);
		script.setVariable("CustomShader", CustomShader_Helper);
		script.setVariable("FlxControls", FlxControls);
		script.setVariable("FlxAxes", FlxAxes);
		script.setVariable("save", modSaves[mod]);
        script.setVariable("flashingLights", Settings.engineSettings.data.flashingLights == true);

		script.setVariable("ModState", ModState);
		script.setVariable("ModSubState", ModSubState);
		script.setVariable("ModSprite", ModSprite);
        
		script.setVariable("AtlasFrameMaker", AtlasFrameMaker);
		script.setVariable("FlxTilemap", FlxTilemap);
		script.setVariable("BlendMode", {
            ADD: BlendMode.ADD,
            ALPHA: BlendMode.ALPHA,
            DARKEN: BlendMode.DARKEN,
            DIFFERENCE: BlendMode.DIFFERENCE,
            ERASE: BlendMode.ERASE,
            HARDLIGHT: BlendMode.HARDLIGHT,
            INVERT: BlendMode.INVERT,
            LAYER: BlendMode.LAYER,
            LIGHTEN: BlendMode.LIGHTEN,
            MULTIPLY: BlendMode.MULTIPLY,
            NORMAL: BlendMode.NORMAL,
            OVERLAY: BlendMode.OVERLAY,
            SCREEN: BlendMode.SCREEN,
            SHADER: BlendMode.SHADER,
            SUBTRACT: BlendMode.SUBTRACT
        });

        script.mod = mod;
    }
    public static function parseSongConfig() {
        var songName = PlayState._SONG.song.toLowerCase();
        var songCodePath = Paths.modsPath + '/$currentMod/song_conf';

        var songConf = SongConf.parse(PlayState.songMod, PlayState.SONG.song, PlayState.SONG);

        scripts = songConf.scripts;
        song_cutscene = songConf.cutscene;
        song_end_cutscene = songConf.end_cutscene;
    }

    

    // UNUSED
    public static function getFreeplaySongs():Array<String> {
        var folders:Array<String> = [];
        var songs:Array<String> = [];
        #if sys
            var folders:Array<String> = sys.FileSystem.readDirectory(Paths.modsPath + "/");
        #end

        for (mod in folders) {
            trace(mod);
            var freeplayList:String = "";
            #if sys
                try {
                    freeplayList = Paths.getMatchPath(Paths.modsPath + "/" + mod + "/data/freeplaySonglist.txt", function(hell:String) { return sys.io.File.getContent(hell); });
                } catch(e) {
                    freeplayList = "";
                }
            #end
            for(s in freeplayList.trim().replace("\r", "").split("\n")) if (s != "") songs.push('$mod:$s');
        }
        return songs;
    }
}
