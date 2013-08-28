package flixel.addons.ui;
import flash.display.Bitmap;
import flash.errors.Error;
import flash.geom.Point;
import flash.geom.Rectangle;
import haxe.xml.Fast;
import flash.display.BitmapData;
import flash.Lib;
import openfl.Assets;
import flixel.FlxBasic;
import flixel.ui.FlxButton;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.util.FlxPoint;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.addons.ui.IEventGetter;
import flixel.addons.ui.IResizable;


/**
 * A simple xml-driven user interface
 * 
 * Usage example:
	_ui = new FlxUI(U.xml("save_slot"),this);
	add(_ui);
 * 
 * @author Lars Doucet
 */

class FlxUI extends FlxUIGroup implements IEventGetter
{
	
	//If this is true, the first few frames after initialization ignore all input so you can't auto-click anything
	public var do_safe_input_delay:Bool = true;
	public var safe_input_delay_time:Float = 0.01;
	
	public var failed:Bool = false;
	public var failed_by:Float = 0;
	
	public var tongue(get, set):IFireTongue;
	public function get_tongue():IFireTongue { return _ptr_tongue; }
	public function set_tongue(t:IFireTongue):IFireTongue {
		_ptr_tongue = t;		
		_tongueSet(members, t);
		return _ptr_tongue;
	}	
	
	private var _ptr_tongue:IFireTongue;
	private var _data:Fast;
		
	private static var _flashRect:Rectangle;
	private static var _flashRect2:Rectangle;
	private static var _flashPoint:Point;
	private static var _flashPointZero:Point;
	
	private static var _assets_init:Bool = false;
	
	/**Make sure to recursively propogate the tongue pointer 
	 * down to all my members
	 */
	private function _tongueSet(list:Array<FlxBasic>,tongue:IFireTongue):Void {		
		for (fb in list) {
			if (Std.is(fb, FlxUIGroup)) {
				var g:FlxUIGroup = cast(fb, FlxUIGroup);
				_tongueSet(g.members, tongue);
			}else if (Std.is(fb, FlxUI)) {
				var fu:FlxUI = cast(fb, FlxUI);
				fu.tongue = tongue;
			}
		}
	}
	
	/***EVENT HANDLING***/
	
	public function getEvent(id:String, sender:Dynamic, data:Dynamic):Void {
		//not yet implemented
	}
	
	public function getRequest(id:String, sender:Dynamic, data:Dynamic):Dynamic {
		//not yet implemented
		return null;
	}
		
	/***PUBLIC FUNCTIONS***/
		
	public function new(data:Fast=null,ptr:IEventGetter=null,superIndex_:FlxUI=null,tongue_:IFireTongue=null) 
	{
		if (_assets_init == false) {
			FlxUIAssets.init();
			_assets_init = true;
		}
		
		//to help with drawing
		if(_flashRect == null){
			_flashRect = new Rectangle();
			_flashRect2 = new Rectangle();
			_flashPoint = new Point();
			_flashPointZero = new Point();
		}
		
		super();
		_ptr_tongue = tongue_;	//set the localization data structure, if any.
								//we set this directly b/c no children have been created yet
								//when children FlxUI elements are added, this pointer is passed down
								//on destroy(), it is recurvisely removed from all of them
		_ptr = ptr;
		if (superIndex_ != null) {
			setSuperIndex(superIndex_);
		}
		if(data != null){
			load(data);
		}
	}
		
	/**
	 * Set a pointer to another FlxUI for the purposes of indexing
	 * @param	flxUI
	 */
	
	public function setSuperIndex(flxUI:FlxUI):Void {
		_superIndexUI = flxUI;
	}
	
	public override function update():Void {
		if (do_safe_input_delay) {
			_safe_input_delay_elapsed += FlxG.elapsed;
			if (_safe_input_delay_elapsed > safe_input_delay_time) {
				do_safe_input_delay = false;
			}else {
				return;
			}
		}
				
		super.update();
	}
	
	/**
	 * Removes an asset
	 * @param	key the asset to remove
	 * @param	destroy whether to destroy it
	 * @return	the asset, or null if destroy=true
	 */
	
	public function removeAsset(key:String,destroy:Bool=true):FlxBasic{
		var asset:FlxBasic = getAsset(key, false);
		if (asset != null) {
			replaceInGroup(asset, null, true);
			_asset_index.remove(key);
		}
		if (destroy) {
			asset.destroy();
			asset = null;
		}
		return asset;
	}
	
	/**
	 * Replaces an asset, both in terms of location & group position
	 * @param	key the string id of the original
	 * @param	replace the replacement object
	 * @param 	destroy_old kills the original if true
	 * @return	the old asset, or null if destroy_old=true
	 */
	
	public function replaceAsset(key:String, replace:FlxBasic, center_x:Bool=true, center_y:Bool=true, destroy_old:Bool=true):FlxBasic{
		//get original asset
		var original:FlxBasic = getAsset(key, false);
		
		if(original != null){
			//set replacement in its location
			if (Std.is(original, FlxObject) && Std.is(replace, FlxObject)) {
				var r:FlxObject = cast(replace, FlxObject);
				var o:FlxObject = cast(original, FlxObject);
				if(!center_x){
					r.x = o.x;
				}else {
					r.x = o.x + (o.width-r.width) / 2;
				}
				if (!center_y) {
					r.y = o.y;
				}else {
					r.y = o.y + (o.height - o.height) / 2;
				}
				r = null; o = null;
			}
			
			//switch original for replacement in whatever group it was in
			replaceInGroup(original, replace);
			
			//remove the original asset index key
			_asset_index.remove(key);
			
			//key the replacement to that location
			_asset_index.set(key, replace);
			
			//destroy the original if necessary
			if (destroy_old) {
				original.destroy();
				original = null;
			}
		}
		
		return original;
	}
	
	
	
	/**
	 * Remove all the references and pointers, then destroy everything
	 */
	
	public override function destroy():Void {
		if(_group_index != null){
			for (key in _group_index.keys()) {
				_group_index.remove(key);
			}_group_index = null;
		}
		if(_asset_index != null){
			for (key in _asset_index.keys()) {
				_asset_index.remove(key);
			}_asset_index = null;			
		}
		if (_definition_index != null) {
			for (key in _definition_index.keys()) {
				_definition_index.remove(key);
			}_definition_index = null;
		}
		_superIndexUI = null;
		_ptr_tongue = null;
		super.destroy();	
	}
	
	/**
	 * Main setup function - pass in a Fast(xml) object 
	 * to set up your FlxUI
	 * @param	data
	 */
	
	public function load(data:Fast):Void {
		_group_index = new Map<String,FlxUIGroup>();
		_asset_index = new Map<String,FlxBasic>();
		_definition_index = new Map<String,Fast>();
		_mode_index = new Map<String,Fast>();
		
		if (data != null) {
			
			_data = data;
			
			//See if there's anything to include
			if (data.hasNode.include) {
				for (inc_data in data.nodes.include) {
					var inc_id:String = inc_data.att.id;
					var inc_xml:Fast = U.xml(inc_id);
					if(inc_xml != null){
						for (def_data in inc_xml.nodes.definition) {
							//add a prefix to avoid collisions:
							var def_id:String = "include:"+def_data.att.id;
							_definition_index.set(def_id, def_data);
							
							//DON'T recursively search for further includes. 
							//Search 1 level deep only!
							//Ignore everything else in the include file
						}
					}
				}
			}
			
			//First, load all our definitions
			if (data.hasNode.definition) {
				for (def_data in data.nodes.definition) {
					var def_id:String = def_data.att.id;
					_definition_index.set(def_id, def_data);					
				}
			}
		
			//Next, load all our modes
			if (data.hasNode.mode) {
				for (mode_data in data.nodes.mode) {
					var mode_id:String = mode_data.att.id;
					_mode_index.set(mode_id, mode_data);
				}
			}
		
			
			//Then, load all our group definitions
			if(data.hasNode.group){
				for (group_data in data.nodes.group) {
					
					//Create FlxUIGroup's for each group we define
					var id:String = group_data.att.id;
					var group:FlxUIGroup = new FlxUIGroup();					
					group.str_id = id;
					_group_index.set(id, group);
					add(group);
					
					// TODO - CREATE ATLAS COMMENTED FOR CPP TARGET.
					/*#if (cpp || neko)
						group.makeAtlas(str_id, FlxG.width, FlxG.height);
					#end*/
					
					FlxG.log.add("Creating group (" + id + ")");
				}
			}
					
			
			#if debug
				//Useful debugging info, make sure things go in the right group:
				FlxG.log.add("Member list...");
				for (fb in members) {
					if (Std.is(fb, FlxUIGroup)) {
						var g:FlxUIGroup = cast(fb, FlxUIGroup);
						FlxG.log.add("-->Group(" + g.str_id + "), length="+g.members.length);						
						for (fbb in g.members) {
							FlxG.log.add("---->Member(" + fbb + ")");
						}
					}else {
						FlxG.log.add("-->Thing(" + fb + ")");
					}
				}			
			#end
			
			
			if (data.x.firstElement() != null) {
				//Load the actual things
				var node:Xml;
				for (node in data.x.elements()) 
				{
					var type:String = node.nodeName;
					type.toLowerCase();
					var obj:Fast = new Fast(node);
					var group_id:String="";
					var group:FlxUIGroup = null;		
									
					var thing_id:String = U.xml_str(obj.x, "id", true);
										
					//If it belongs to a group, get that information ready:
					if (obj.has.group) { 
						group_id = obj.att.group; 
						group = getGroup(group_id);
					}
					
					//Make the thing
					var thing:FlxBasic = _loadThing(type,obj);
					
					if (thing != null) {

						if (group != null) {
							group.add(thing);
						}else {
							add(thing);			
						}		
						
						_loadPosition(obj, thing);	//Position the thing if possible						
						
						if (thing_id != "") {
							_asset_index.set(thing_id, thing);
						}
					}
				}				
			}	
			
			_postLoad(data);
		}else {
			_onFinishLoad();
		}	
	}
	
	private function _postLoad(data:Fast):Void {
		
		if (data.x.firstElement() != null) {
			//Load the actual things
			var node:Xml;
			for (node in data.x.elements()) 
			{
				_postLoadThing(node.nodeName.toLowerCase(), new Fast(node));					
			}
		}
			
		if (_failure_checks != null) {
			for (data in _failure_checks) {					
				if (_checkFailure(data)) {
					failed = true;
					break;
				}
			}
			U.clearArraySoft(_failure_checks);
			_failure_checks = null;
		}		
		
		_onFinishLoad();
	}
	
	/**
	 * Set a mode for this UI. This lets you show/hide stuff basically. 
	 * @param	mode_id The mode you want, say, "empty" or "play" for a save slot
	 * @param	target_id UI element to target - "" for the UI itself, otherwise the id of an element that is itself a FlxUI
	 */
	
	public function setMode(mode_id:String,target_id:String=""):Void {
		var mode:Fast = getMode(mode_id);
		var id:String = "";
		var thing:FlxBasic;
		if(target_id == ""){			
			if (mode != null) {
				if (mode.hasNode.show) {
					for (show_node in mode.nodes.show) {
						id = show_node.att.id;
						thing = getAsset(id);
						if (thing != null) {
							thing.visible = true;
						}
					}
				}
				if (mode.hasNode.hide) {
					for (hide_node in mode.nodes.hide) {
						id = hide_node.att.id;
						thing = getAsset(id);
						if (thing != null) {
							thing.visible = false;
						}
					}
				}
			}
		}else {
			var target:FlxBasic = getAsset(target_id);
			if (target != null && Std.is(target, FlxUI)) {
				var targetUI:FlxUI = cast(target, FlxUI);
				targetUI.setMode(mode_id, "");
			}
		}
	}
	
	/******UTILITY FUNCTIONS**********/
	
	public function getGroup(key:String, recursive:Bool=true):FlxUIGroup{
		var group:FlxUIGroup = _group_index.get(key);
		if (group == null && recursive && _superIndexUI != null) {
			return _superIndexUI.getGroup(key, recursive);
		}
		return group;
	}
	
	public function getFlxText(key:String, recursive:Bool = true):FlxText {
		var asset:FlxBasic = getAsset(key, recursive);
		if (asset != null) {
			if (Std.is(asset, FlxText)) {
				return cast(asset, FlxText);
			}
		}
		return null;
	}
	
	public function getAsset(key:String, recursive:Bool=true):FlxBasic{
		var asset:FlxBasic = _asset_index.get(key);
		if (asset == null && recursive && _superIndexUI != null) {
			return _superIndexUI.getAsset(key, recursive);
		}
		return asset;
	}
	
	public function getMode(key:String, recursive:Bool = true):Fast {
		var mode:Fast = _mode_index.get(key);
		if (mode == null && recursive && _superIndexUI != null) {
			return _superIndexUI.getMode(key, recursive);
		}
		return mode;
	}
	
	public function getDefinition(key:String,recursive:Bool=true):Fast{
		var definition:Fast = _definition_index.get(key);
		if (definition == null && recursive && _superIndexUI != null) {
			definition = _superIndexUI.getDefinition(key, recursive);			
		}
		if (definition == null) {	//still null? check the globals:
			if (key.indexOf("include:") == -1) {	
				//check if this definition exists with the prefix "include:"
				//but stop short of recursively churning on "include:include:etc"
				definition = getDefinition("include:" + key, recursive);
			}
		}
		return definition;
	}
	
	/**
	 * Adds to thing.x and/or thing.y with wrappers depending on type
	 * @param	thing
	 * @param	X
	 * @param	Y
	 */
	
	private static inline function _delta(thing:Dynamic, X:Float=0, Y:Float=0):Void {
		if(Std.is(thing,FlxObject)){
			var obj:FlxObject = cast(thing, FlxObject);
			obj.x += X; obj.y += Y;
		}else if (Std.is(thing, FlxUIGroup)) {
			var group:FlxUIGroup = cast(thing, FlxUIGroup);
			group.instant_update = true;
			group.x += Std.int(X); group.y += Std.int(Y);
		}
	}
		
	/**
	 * Centers thing in x axis with wrappers depending on type
	 * @param	thing
	 * @param	amt
	 */
		
	private static inline function _center(thing:Dynamic,X:Bool=true,Y:Bool=true):Dynamic{
		var return_thing:Dynamic = thing;
		if(Std.is(thing,FlxObject)){
			var obj:FlxObject = cast(thing, FlxObject);
			if (X) { obj.x = (FlxG.width - obj.width) / 2; }
			if (Y) { obj.y = (FlxG.height - obj.height) / 2;}
			return_thing = obj;
		}
		return return_thing;
	}
	
	/***PRIVATE***/
		
	private var _group_index:Map<String,FlxUIGroup>;
	private var _asset_index:Map<String,FlxBasic>;
	private var _definition_index:Map<String,Fast>;
	private var _mode_index:Map<String,Fast>;
	private var _ptr:IEventGetter;	

	private var _superIndexUI:FlxUI;
	private var _safe_input_delay_elapsed:Float = 0.0;
	
	private var _failure_checks:Array<Fast>;
	
	/**
	 * Replace an object in whatever group it is in
	 * @param	original the original object
	 * @param	replace	the replacement object
	 * @param	splice if replace is null, whether to splice the entry
	 */

	 
	private function replaceInGroup(original:FlxBasic,replace:FlxBasic,splice:Bool=false){
		//Slow, unoptimized, searches through everything
		if(_group_index != null){
			for (key in _group_index.keys()) {
				var group:FlxUIGroup = _group_index.get(key);
				if (group.members != null) {
					var i:Int = 0;
					for (member in group.members) {
						if (member == original) {
							group.members[i] = replace;
							if (replace == null) {
								if (splice) {
									group.members.splice(i, 1);
									i--;
								}
							}
							return;
						}
						i++;
					}
				}
			}
		}
		
		//if we get here, it's not in any group, it's just in our global member list
		if (this.members != null) {
			var i:Int = 0;
			for (member in this.members) {				
				if (member == original) {
					members[i] = replace;
					if (replace == null) {
						if (splice) {
							members.splice(i, 1);
							i--;
						}
					}
					return;
				}
				i++;
			}
		}
	}
	
	/************LOADING FUNCTIONS**************/
	
	private function _loadThing(type:String, data:Fast):Dynamic {
		var use_def:String = U.xml_str(data.x, "use_def", true);		
		var definition:Fast = null;
		if (use_def != "") {
			definition = getDefinition(use_def);
		}
		
		//If we have per-locale UI tweaks
		if (data.hasNode.locale) {
			
			//Deep-copy the data and definition xml objects
			data = U.copyFast(data);
			if (definition != null) {
				definition = U.copyFast(definition);
			}
			
			//Make any necessary UI adjustments based on locale
			if (_ptr_tongue != null) {
				for (lNode in data.nodes.locale) {
					var lid:String = U.xml_str(lNode.x, "id", true);
					if (lid == _ptr_tongue.locale.toLowerCase()) {
						if (lNode.hasNode.change) {
							for (change in lNode.nodes.change) {
								var xml:Xml;
								for (att in change.x.attributes()) {
									var value:String = change.x.get(att);
									if (data.x.exists(att)) {
										data.x.set(att, value);
									}											
									if (definition != null) {
										if (definition.x.exists(att)) {
											definition.x.set(att, value);
										}
									}
								}
							}
						}
					}
				}
			}
		}
		
		switch(type) {
			case "chrome", "9slicesprite": return _load9SliceSprite(data, definition);
			case "tile_test": return _loadTileTest(data, definition);
			case "sprite": return _loadSprite(data,definition);
			case "text": return _loadText(data, definition);
			case "button": return _loadButton(data, definition);
			
			case "button_toggle": return _loadButton(data, definition,true,true);
						
			case "tab_menu": return _loadTabMenu(data, definition);
			case "checkbox": return _loadCheckBox(data, definition);
			case "radio_group": return _loadRadioGroup(data, definition);
			case "layout", "ui": return _loadLayout(data, definition);
			case "failure": if (_failure_checks == null) { _failure_checks = new Array<Fast>(); }
							_failure_checks.push(data);
							return null;
			case "align": 	_alignThing(data);
							return null;
							
			default: 
				//If I don't know how to load this thing, I will request it from my pointer:			
				var dataObject = { data:data, definition:definition };
				var result = _ptr.getRequest("ui_get:" + type, this, dataObject);
				return result;
		}
		return null;
	}
	
	private function _alignThing(data:Fast):Void {
		var datastr:String = data.x.toString();
		if (data.hasNode.objects) {			
			for (objectNode in data.nodes.objects) {
				var objects:Array<String> = U.xml_str(objectNode.x, "value", true, "").split(",");
			
				var axis:String = U.xml_str(data.x, "axis", true);
				var spacing:Float = U.xml_f(data.x, "spacing", -1);
				var resize:Bool = U.xml_bool(data.x, "resize");
				var bounds:FlxPoint = new FlxPoint(-1,-1);
				
				if (axis != "horizontal" && axis != "vertical") {
					throw new Error("FlxUI._alignThing(): axis must be \"horizontal\" or \"vertical\"!");
					return;
				}			
							
				if (data.hasNode.bounds) {
					var bound_range:Float = -1;
					
					if (axis == "horizontal") {
						bounds.x = _getDataSize("w", U.xml_str(data.node.bounds.x, "left"), -1);
						bounds.y = _getDataSize("w", U.xml_str(data.node.bounds.x, "right"), -1);					
					}else if (axis == "vertical") {
						bounds.x = _getDataSize("h", U.xml_str(data.node.bounds.x, "top"), -1);
						bounds.y = _getDataSize("h", U.xml_str(data.node.bounds.x, "bottom"), -1);
					}
				
					if (bounds.x != -1 && bounds.y != -1) {
						if(bounds.y <= bounds.x){
							throw new Error("FlxUI._alignThing(): bounds max must be > bounds min!");
							return;
						}
					}else {
						throw new Error("FlxUI._alignThing(): missing bound!");
						return;
					}
					
					_doAlign(objects, axis, spacing, resize, bounds);
				
				}else {
					throw new Error("FlxUI._alignThing(): <bounds> node not found!");
					return;
				}
			}
		}else {
			throw new Error("FlxUI._alignThing(): <objects> node not found!");
			return;
		}				
	}
	
	private function _doAlign(objects:Array<String>, axis:String, spacing:Float, resize:Bool, bounds:FlxPoint):Void {
		var total_spacing:Float = 0;
		var total_size:Float = 0;		
		
		var bound_range:Float = bounds.y - bounds.x;
		
		var spaces:Float = objects.length-1;
		var space_size:Float = 0;
		var object_size:Float = 0;
		
		var size_prop:String = "width";
		var pos_prop:String = "x";
		if (axis == "vertical") { 
			size_prop = "height"; 
			pos_prop = "y"; 
		}
		
		//calculate total size of everything
		for (id in objects) {
			var flxb:FlxBasic = getAsset(id);			
			
			
			//use reflection to deal with groups & crap
			//TODO:
			//could be optimized if everything was guaranteed to have those properties
			total_size += Reflect.getProperty(flxb, size_prop);
		}
		
		if (resize == false) {	//not resizing, so space evenly
			total_spacing = bound_range - total_size;
			space_size = total_spacing / spaces;
		}else {					//resizing, calculate space and then get remaining size
			space_size = spacing;
			total_spacing = spacing * spaces;
			object_size = (bound_range - total_spacing) / objects.length;	//target object size
		}
		
		var i:Int = 0;
		var last_pos:Float = bounds.x;
		for (id in objects) {
			var flxb:FlxBasic = getAsset(id);
			var pos:Float = last_pos;
			if (!resize) {
				//if we're not resizing, just get the object's size
				object_size = Reflect.getProperty(flxb, size_prop);
			}else {
				//if we are resizing, resize it to the target size now
				if (Std.is(flxb, flixel.addons.ui.IResizable)) {
					var flxb_r:IResizable = cast flxb;
					if(axis == "vertical"){
						flxb_r.resize(flxb_r.get_width(), object_size);
					}else if (axis == "horizontal") {
						flxb_r.resize(object_size, flxb_r.get_height());
					}
				}
			}
			last_pos = pos + object_size + space_size;
			Reflect.setProperty(flxb, pos_prop, pos);		//set x or y to the correct location
			i++;
		}		
	}
	
	private function _checkFailure(data:Fast):Bool{
		var target:String = U.xml_str(data.x, "target", true);
		var property:String = U.xml_str(data.x, "property", true);
		var compare:String = U.xml_str(data.x, "compare", true);
		var value:String = U.xml_str(data.x, "value", true);
		
		var thing:FlxBasic = getAsset(target);
		
		if (thing == null) {
			return false;
		}
		
		var fo:FlxObject = null;
		
		if (Std.is(thing, FlxObject) == false) {
			return false;
		}else {
			fo = cast thing;
		}
		
		var prop_f:Float = 0;
		var val_f:Float = 0;
				
		var p: { percent:Float, error:Bool } = U.perc_to_float(value);
		
		if (p.error) {
			if (U.isStrNum(value)) {
				val_f = Std.parseFloat(value);
			}else {
				return false;
			}
		}
		
		switch(property) {
			case "w", "width": prop_f = fo.width; 
							   if (!p.error) { val_f = p.percent * thisWidth(); }
							   
			case "h", "height": prop_f = fo.height; 
							   if (!p.error) { val_f = p.percent * thisHeight();}
		}
		
		var return_val:Bool = false;
		
		switch(compare) {
			case "<": if (prop_f < val_f) {
						failed_by = val_f - prop_f;
						return_val = true;
					  }
			case ">": if (prop_f > val_f) {
						failed_by = prop_f - val_f;
						return_val = true;
					  }
			case "=", "==": if (prop_f == val_f) {
						failed_by = Math.abs(prop_f - val_f);
						return_val = true;
					  }
			case "<=": if (prop_f <= val_f) {
						failed_by = val_f - prop_f;
						return_val = true;
					  }
			case ">=": if (prop_f >= val_f) {
						failed_by = prop_f - val_f;
						return_val = true;
					  }
		}
	
		return return_val;
	}
	
	private function _resizeThing(fo_r:IResizable, bounds:{ min_width:Float, min_height:Float,
														 max_width:Float, max_height:Float}):Void {
		var do_resize:Bool = false;
		var ww:Float = fo_r.get_width();
		var hh:Float = fo_r.get_height();
		
		if (ww < bounds.min_width) {
			do_resize = true; 
			ww = bounds.min_width;
		}else if (ww > bounds.max_width) {
			do_resize = true;
			ww = bounds.max_width;
		}
		
		if (hh < bounds.min_height) {
			do_resize = true;
			hh = bounds.min_height;
		}else if (hh > bounds.max_height) {
			do_resize = true;
			hh = bounds.max_height;
		}
		
		if (do_resize) {
			fo_r.resize(ww,hh);
		}
	}
	
	private function _postLoadThing(type:String, data:Fast):Void {
		
		var id:String = U.xml_str(data.x, "id", true);
		var fb:FlxBasic = getAsset(id);
		
		#if debug
		trace("FlxUI._postLoadThing(" + type + ") id=" + id);
		#end
		
		if (type == "align") {
			_alignThing(data);
		}
		
		if (fb == null) {
			return;
		}
		
		var use_def:String = U.xml_str(data.x, "use_def", true);		
		var definition:Fast = null;
		if (use_def != "") {
			definition = getDefinition(use_def);
		}		
		
		if (Std.is(fb, IResizable)) {
			var bounds: { min_width:Float, min_height:Float, 
			              max_width:Float, max_height:Float } = calcMaxMinSize(data);				
			
			_resizeThing(cast(fb, IResizable), bounds);		
			
		}						
		
		var fbx:Float=0;
		var fby:Float=0;
				
		if (Std.is(fb, FlxObject)) {
			var fo:FlxObject = cast fb;
			fbx = fo.x; fby = fo.y;
		}else if (Std.is(fb, FlxUIGroup)) {
			var fg:FlxUIGroup = cast fb;
			fbx = fg.x; fby = fg.y;
		}
		
		_delta(fb, -fbx, -fby);			//reset position to 0,0
		_loadPosition(data,fb);			//reposition
	}
	
	private function _loadTileTest(data:Fast, definition:Fast = null):FlxUITileTest {
		var the_data:Fast = data;
		if (definition != null) { the_data = definition; }
		
		var tiles_w:Int = U.xml_i(data.x, "tiles_w", 2);
		var tiles_h:Int = U.xml_i(data.x, "tiles_h", 2);
		var w:Float = U.xml_f(data.x, "width");
		var h:Float = U.xml_f(data.x, "height");
		
		var bounds: { min_width:Float, min_height:Float, 
			          max_width:Float, max_height:Float } = calcMaxMinSize(data);				
		
		if (w < bounds.min_width) { w = bounds.min_width; }
		if (h < bounds.min_height) { h = bounds.min_height; }
		
		var tileWidth:Int = Std.int(w/tiles_w);
		var tileHeight:Int = Std.int(h/tiles_h);
		
		if (tileWidth < tileHeight) { tileHeight = tileWidth; }
		else if (tileHeight < tileWidth) { tileWidth = tileHeight; }
		
		var totalw:Float = tileWidth * tiles_w;
		var totalh:Float = tileHeight * tiles_h;
		
		if (totalw > bounds.max_width) { tileWidth = Std.int(bounds.max_width / tiles_w); }
		if (totalh > bounds.max_height) { tileHeight = Std.int(bounds.max_height / tiles_h); }
		
		if (tileWidth < tileHeight) { tileHeight = tileWidth; }
		else if (tileHeight < tileWidth) { tileWidth = tileHeight; }
		
		if (tileWidth < 2) { tileWidth = 2; }
		if (tileHeight < 2) { tileHeight = 2; }
		
		var ftt:FlxUITileTest = new FlxUITileTest(0, 0, tileWidth, tileHeight, tiles_w, tiles_h);
		return ftt;
	}
	
	private function _loadText(data:Fast,definition:Fast=null):FlxText{
		var the_data:Fast = data;
		if (definition != null) { the_data = definition;}
		
		var text:String = U.xml_str(data.x, "text");
		var context:String = U.xml_str(data.x, "context", true, "ui");
		text = getText(text,context);
				
		var W:Int = U.xml_i(data.x, "width"); if (W == 0) { W = 100; }
		
		var the_font:String = _loadFontFace(the_data);
		
		var input:Bool = U.xml_bool(the_data.x, "input");
		
		var align:String = U.xml_str(the_data.x, "align"); if (align == "") { align = null;}
		var size:Int = U.xml_i(the_data.x, "size"); if (size == 0) { size = 8;}
		var color:Int = _loadColor(the_data);
		var shadow:Int = U.xml_i(the_data.x, "shadow");
		var drop_shadow:Bool = U.xml_str(the_data.x, "drop_shadow", true) == "true";
				
		var ft:FlxText;
		if(input == false){
			var ftu:FlxUIText = new FlxUIText(0, 0, W, text, size);
			ftu.setFormat(the_font, size, color, align, shadow,shadow!=0);
			ftu.dropShadow = drop_shadow;
			ftu.forceCalcFrame();
			ft = ftu;
		}else {
			var fti:FlxUIInputText = new FlxUIInputText(0, 0, W, text);
			fti.setFormat(the_font, size, color, align, shadow,shadow!=0);			
			fti.forceCalcFrame();
			ft = fti;
		}		
		return ft;
	}
	
	private function _loadRadioGroup(data:Fast, definition:Fast = null):FlxUIRadioGroup {
		var frg:FlxUIRadioGroup = null;
		
		var default_data:Fast = data;
		if (definition != null) { default_data = definition; }
		
		var dot_src:String = U.xml_str(default_data.x, "dot_src", true);
		var radio_src:String = U.xml_str(default_data.x, "radio_src", true);
		
		var labels:Array<String> = new Array<String>();
		var ids:Array<String> = new Array<String>();
		
		var W:Int = U.xml_i(default_data.x, "radio_width", 11);
		var H:Int = U.xml_i(default_data.x, "radio_height", 11);
		
		var labelW:Int = U.xml_i(default_data.x, "label_width", 100);
		
		for (radioNode in data.nodes.radio) {
			var id:String = U.xml_str(radioNode.x, "id", true);
			var label:String = U.xml_str(radioNode.x, "label");
			
			var context:String = U.xml_str(radioNode.x, "context", true, "ui");
			label = getText(label,context);
		
			ids.push(id);
			labels.push(label);
		}
		
		var y_space:Float = U.xml_f(data.x, "y_space", 25);
		
		var params:Array<Dynamic> = getParams(data);
		
		var radio_asset:String = null;
		if (radio_src != "") {
			radio_asset = U.gfx(radio_src);		
		}
			
		var dot_asset:Dynamic=null;
		if (dot_src != "") {
			dot_asset = U.gfx(dot_src);
		}
		
		//if radio_src or dot_src are == "", then leave radio_asset/dot_asset == null, 
		//and FlxUIRadioGroup will default to defaults defined in FlxUIAssets 
		
		frg = new FlxUIRadioGroup(0, 0, ids, labels, _onClickRadioGroup, y_space, W, H, labelW);
						
		if (radio_asset != "" && radio_asset != null) {
			frg.loadGraphics(radio_asset,dot_asset);
		}
		
		var text_x:Int = U.xml_i(default_data.x, "text_x");
		var text_y:Int = U.xml_i(default_data.x, "text_y");		
		
		for (fo in frg.members) {
			if (Std.is(fo, FlxUICheckBox)){
				var fc:FlxUICheckBox = cast(fo, FlxUICheckBox);
				formatButtonText(default_data, fc);
				fc.textX = text_x;				
				fc.textY = text_y;
			}
		}
						
		return frg;
	}
	
	private function _loadCheckBox(data:Fast, definition:Fast = null):FlxUICheckBox {
		var src:String = "";
		var fc:FlxUICheckBox = null;
		
		var default_data:Fast = data;
		if (definition != null) { default_data = definition; }
		
		var label:String = U.xml_str(data.x, "label");
		var context:String = U.xml_str(data.x, "context", true, "ui");
		label = getText(label,context);
		
		var context:String = U.xml_str(data.x, "context", true, "ui");
		label = getText(label,context);
			
		var labelW:Int = U.xml_i(default_data.x, "label_width", 100);
		
		var check_src:String = U.xml_str(default_data.x, "check_src", true);
		var box_src:String = U.xml_str(default_data.x, "box_src", true);
		
		var params:Array<Dynamic> = getParams(data);
				
		var box_asset:String = null; 
		var check_asset:String = null;  
		
		if(box_src != ""){
			box_asset = U.gfx(box_src);		
		}
		if(check_src != ""){
			check_asset = U.gfx(check_src);		
		}
		
		fc = new FlxUICheckBox(0, 0, box_asset, check_asset, label, labelW, _onClickCheckBox, params);
		formatButtonText(default_data, fc);
		
		var text_x:Int = U.xml_i(default_data.x, "text_x");
		var text_y:Int = U.xml_i(default_data.x, "text_y");		
		
		fc.textX = text_x;
		fc.textY = text_y;
		
		fc.text = label;
								
		return fc;
	}
	
	private function _loadLayout(data:Fast, definition:Fast = null):FlxUI{
		var default_data:Fast = data;
		if (definition != null) { default_data = definition;}
				
		var id:String = U.xml_str(data.x, "id", true);
		var _ui:FlxUI = new FlxUI(data, this, this,_ptr_tongue);
		_ui.str_id = id;
		
		return _ui;
	}
	
	private function _loadTabMenu(data:Fast, definition:Fast = null):FlxUITabMenu{
		var default_data:Fast = data;
		if (definition != null) { default_data = definition;}
		
		var back_def_str:String = U.xml_str(default_data.x, "back_def");
		var back_def:Fast = getDefinition(back_def_str);
		if (back_def == null) {
			back_def = default_data;
		}
		
		var back:FlxUI9SliceSprite = _load9SliceSprite(data, back_def, "tab_menu");
		
		var tab_def:Fast = null;
		
		var stretch_tabs:Bool = U.xml_bool(default_data.x, "stretch_tabs",false);
		
		if (default_data.hasNode.tab) {
			var tab_def_str:String = U.xml_str(default_data.node.tab.x, "use_def");
			if (tab_def_str != "") {
				tab_def = getDefinition(tab_def_str);
			}else {
				tab_def = default_data.node.tab;
			}
		}
		
		var list_tabs:Array<FlxUIButton> = new Array<FlxUIButton>();
		
		var id:String = "";
		
		if (data.hasNode.tab) {			
			for (tab_node in data.nodes.tab) {
				id = U.xml_str(tab_node.x, "id", true);
				var label:String = U.xml_str(tab_node.x, "label");
				var context:String = U.xml_str(tab_node.x, "context", true, "ui");
				label = getText(label,context);
		
				var context:String = U.xml_str(tab_node.x, "context", true, "ui");
				label = getText(label,context);
		
				var tab:FlxUIButton = _loadButton(tab_node, tab_def, true, true, "tab_menu");				
				tab.id = id;
				list_tabs.push(tab);
			}			
		}
		
		if (list_tabs.length > 0) {
			if (tab_def == null || !tab_def.hasNode.text) {
				for (t in list_tabs) {
					t.label.color = 0xFFFFFF;
					t.label.shadow = 0;
					t.label.useShadow = true;
				}
			}
			
			if (tab_def == null || !tab_def.has.width) {	//no tab definition!
				stretch_tabs = true;
				//make sure to stretch the default tab graphics
			}
		}
		
		var fg:FlxUITabMenu = new FlxUITabMenu(back,list_tabs,stretch_tabs);		
		
		if (data.hasNode.group) {
			for (group_node in data.nodes.group) {
				id = U.xml_str(group_node.x, "id", true);
				var _ui:FlxUI = new FlxUI(group_node, fg, this,_ptr_tongue);
				_ui.str_id = id;
				fg.addGroup(_ui);
			}
		}		
		
		//fg.selected_tab = 0;
		
		return fg;
	}
			
	private function _loadButton(data:Fast, definition:Fast = null, setCallback:Bool = true, isToggle:Bool = false, load_code:String=""):FlxUIButton {
		var src:String = ""; 
		var fb:FlxUIButton = null;
				
		var default_data:Fast = data;
		if (definition != null) { default_data = definition;}
		
		var resize_ratio:Float = U.xml_f(data.x, "resize_ratio", -1);
		var isVis:Bool = U.xml_bool(data.x, "visible", true);		
		
		var label:String = U.xml_str(data.x, "label");
		var context:String = U.xml_str(data.x, "context", true, "ui");
		label = getText(label,context);
		
		var W:Int = U.xml_i(default_data.x, "width");
		var H:Int = U.xml_i(default_data.x, "height");	
				
		var params:Array<Dynamic> = getParams(data);
		
		fb = new FlxUIButton(0, 0, label);			
		fb.resize_ratio = resize_ratio;
		
		if (setCallback) {
			fb.setOnUpCallback(_onClickButton, [params]);
		}
		
		/***Begin graphics loading block***/
		
		if (default_data.hasNode.graphic) {
			
			var blank:Bool = U.xml_bool(default_data.node.graphic.x, "blank");
			
			if (blank) {
				//load blank
				fb.loadGraphicSlice9(["","",""], W, H);
			}else{
			
				var graphic_ids:Array<String>;
				var slice9_ids:Array<String>;
				
				if (isToggle) {
					graphic_ids = ["", "", "", "", "", ""];
					slice9_ids= ["", "", "", "", "", ""];
				}else {				
					graphic_ids = ["", "", ""];
					slice9_ids = ["", "", ""];
				}
				
				for (graphicNode in default_data.nodes.graphic) {
					var graphic_id:String = U.xml_str(graphicNode.x, "id", true);
					var image:String = U.xml_str(graphicNode.x, "image");
					var slice9:String = U.xml_str(graphicNode.x, "slice9");
					var toggleState:Bool = U.xml_bool(graphicNode.x, "toggle");
					toggleState = toggleState && isToggle;
					
					switch(graphic_id) {
						case "inactive", "", "normal", "up": 
							if (image != "") { 
								if(!toggleState){
									graphic_ids[0] = U.gfx(image); 
								}else {
									graphic_ids[3] = U.gfx(image);
								}
							}
							slice9_ids[0] = slice9;
						case "active", "highlight", "hilight", "over", "hover": 
							if (image != "") { 
								if(!toggleState){
									graphic_ids[1] = U.gfx(image); 
								}else {
									graphic_ids[4] = U.gfx(image);
								}
							}
							slice9_ids[1] = slice9;
						case "down", "pressed", "pushed":
							if (image != "") { 
								if(!toggleState){
									graphic_ids[2] = U.gfx(image); 
								}else {
									graphic_ids[5] = U.gfx(image);
								}
							}
							slice9_ids[2] = slice9;
						case "all":
							if (image != "") { 
								graphic_ids = [U.gfx(image)]; 							
							}
							slice9_ids = [slice9];
					}
	
					if (graphic_ids[0] != "") {
						if (graphic_ids.length >= 3) {
							if (graphic_ids[1] == "") {		//"over" is undefined, grab "up"
								graphic_ids[1] = graphic_ids[0];
							}
							if (graphic_ids[2] == "") {		//"down" is undefined, grab "over"
								graphic_ids[2] = graphic_ids[1];
							}
							if (graphic_ids.length >= 6) {	//toggle states
								if (graphic_ids[3] == "") {	//"up" undefined, grab "up" (untoggled)
									graphic_ids[3] = graphic_ids[0];
								}
								if (graphic_ids[4] == "") {	//"over" grabs "over"
									graphic_ids[4] = graphic_ids[1];
								}
								if (graphic_ids[5] == "") {	//"down" grabs "down"
									graphic_ids[5] = graphic_ids[2];
								}
							}
						}
					}
				}
				
				//load 9-slice
				fb.loadGraphicSlice9(graphic_ids, W, H, slice9_ids, -1, isToggle);
			}
		}else {			
			if(load_code == "tab_menu"){
				//load default tab menu graphics
				var graphic_ids:Array<String> = [FlxUIAssets.IMG_TAB_BACK, FlxUIAssets.IMG_TAB_BACK, FlxUIAssets.IMG_TAB_BACK, FlxUIAssets.IMG_TAB, FlxUIAssets.IMG_TAB, FlxUIAssets.IMG_TAB];
				var slice9_ids:Array<String> = [FlxUIAssets.SLICE9_TAB, FlxUIAssets.SLICE9_TAB, FlxUIAssets.SLICE9_TAB, FlxUIAssets.SLICE9_TAB, FlxUIAssets.SLICE9_TAB, FlxUIAssets.SLICE9_TAB];
				fb.loadGraphicSlice9(graphic_ids, W, H, slice9_ids, -1, isToggle);
			}else{
				//load default graphics			
				fb.loadGraphicSlice9(null, W, H, null, -1, isToggle);
			}
		}		
		
		/***End graphics loading block***/
			
		formatButtonText(default_data, fb);
		
		var text_x:Int = 0;
		var text_y:Int = 0;
		if (data.x.get("text_x") != null) {
			text_x = U.xml_i(data.x, "text_x");			
		}else {
			text_x = U.xml_i(default_data.x, "text_x");
		}
			
		if (data.x.get("text_y") != null) {
			text_y = U.xml_i(data.x, "text_y");			
		}else {
			text_y = U.xml_i(default_data.x, "text_y");
		}		
		
		//label offset has already been 'centered,' this adjust from there:
		fb.labelOffset.x += text_x;
		fb.labelOffset.y += text_y;		
		
		fb.visible = isVis;
		
		return fb;
	}
	 		
	private static inline function _loadBitmapRect(source:String,rect_str:String):BitmapData {
		var b1:BitmapData = Assets.getBitmapData(U.gfx(source));
		var r:Rectangle = FlxUI9SliceSprite.getRectFromString(rect_str);
		var b2:BitmapData = new BitmapData(Std.int(r.width), Std.int(r.height), true, 0x00ffffff);					
		b2.copyPixels(b1, r, new Point(0, 0));
		return b2;
	}
	
	private function _load9SliceSprite(data:Fast,definition:Fast=null,load_code:String=""):FlxUI9SliceSprite{
		var src:String = ""; 
		var f9s:FlxUI9SliceSprite = null;
				
		var the_data:Fast = data;
		if (definition != null) { the_data = definition;}
		
		var resize_ratio:Float = U.xml_f(data.x, "resize_ratio", -1);
		
		var bounds: { min_width:Float, min_height:Float, 
			          max_width:Float, max_height:Float } = calcMaxMinSize(data);				
							  
		src = U.xml_gfx(the_data.x, "src");
		if (src == "") { src = null; }
		
		if(src == null){
			if (load_code == "tab_menu") {
				src = FlxUIAssets.IMG_CHROME_FLAT;
			}
		}
		
		var rc:Rectangle;
		var rect_w:Int = U.xml_i(data.x, "width");
		var rect_h:Int = U.xml_i(data.x, "height");
		
		if (rect_w < bounds.min_width) { rect_w = cast bounds.min_width; }
		else if (rect_w > bounds.max_width) { rect_w = cast bounds.max_width; }
		
		if (rect_h < bounds.min_height) { rect_h = cast bounds.min_height; }
		else if (rect_h > bounds.max_height) { rect_h = cast bounds.max_height; }
		
		if (rect_w == 0 || rect_h == 0) {
			return null;
		}
		
		var rc:Rectangle = new Rectangle(0, 0, rect_w, rect_h);
		var slice9:String = U.xml_str(the_data.x, "slice9");
		var tile:Bool = U.xml_bool(the_data.x, "tile", false);
		var smooth:Bool = U.xml_bool(the_data.x, "smooth", false);
				
		f9s = new FlxUI9SliceSprite(0, 0, src, rc, slice9, tile, smooth,"",resize_ratio);
		
		return f9s;
	}
	
	private function _loadSprite(data:Fast,definition:Fast=null):FlxUISprite{
		var src:String = ""; 
		var fs:FlxUISprite = null;
		
		var the_data:Fast = data;
		if (definition != null) { the_data = definition;}
		
		src = U.xml_gfx(the_data.x, "src");
		
		var bounds: { min_width:Float, min_height:Float, 
			          max_width:Float, max_height:Float } = calcMaxMinSize(data);				
				
		if(src != ""){
			fs = new FlxUISprite(0, 0, src);		
		}else {
			var W:Int = U.xml_i(the_data.x, "width");
			var H:Int = U.xml_i(the_data.x, "height");
			
			if (W < bounds.min_width) { W = cast bounds.min_width; }
			else if (W > bounds.max_width) { W = cast bounds.max_width; }
			if (H < bounds.min_height) { H = cast bounds.max_height; }
			else if (H > bounds.max_height) { H = cast bounds.max_height;}			
			
			var C:Int = U.parseHex(U.xml_str(the_data.x, "color"),true);
			fs = new FlxUISprite(0, 0);
			fs.makeGraphic(W, H, C);
		}
		
		return fs;
	}
	
	private function thisWidth():Int {
		//if (_ptr == null || Std.is(_ptr, FlxUI) == false) {
			return FlxG.width;
		/*}
		var ptrUI:FlxUI = cast _ptr;
		return Std.int(ptrUI.width);*/
	}
	
	private function thisHeight():Int {
		//if (_ptr == null || Std.is(_ptr, FlxUI) == false) {
			return FlxG.height;
		/*}
		var ptrUI:FlxUI = cast _ptr;
		return Std.int(ptrUI.height);*/
	}
		
	private function _getAnchorPos(thing:FlxBasic, axis:String, str:String):Float {
		switch(str) {
			case "": return 0;
			case "left": return 0;
			case "right": return thisWidth();
			case "top", "up": return 0;
			case "bottom", "down": return thisHeight();
			default:
				var perc: { percent:Float, error:Bool } = U.perc_to_float(str);
				if (!perc.error) {
					if (axis == "x") {
						return perc.percent * thisWidth();
					}else if (axis == "y") {
						return perc.percent * thisHeight();
					}
				}else {
					var r:EReg = ~/[\w]+\.[\w]+/;
					var property:String = "";
					if (r.match(str)) {
						var p: { pos:Int, len:Int }= r.matchedPos();
						if (p.pos == 0 && p.len == str.length) {
							var arr:Array<String> = str.split(".");
							str = arr[0];
							property = arr[1];
						}
					}
					
					var otherb:FlxBasic = getAsset(str);
					var other:FlxObject;
					var otherx:Float;
					var othery:Float;
					var otherw:Float;
					var otherh:Float;
					if (Std.is(otherb, FlxObject)) {
						other = cast otherb;
						otherx = other.x;		othery = other.y;
						otherw = other.width;	otherh = other.height;
					}else if (Std.is(otherb, FlxUIGroup)) {
						var fgx:FlxUIGroup = cast otherb;
						otherx = fgx.x;		othery = fgx.y;
						otherw = fgx.width; otherh = fgx.height;
					}else {
						return 0;
					}
					
					if (thing != null) {
						if (axis == "x") { 
							switch(property) {
								case "left": return otherx;
								case "right": return otherx + otherw;
								case "center": return otherx + otherw / 2;
								default:return otherx; 
							}
						}
						else if (axis == "y") { 
							switch(property) {
								case "top": return othery;
								case "bottom": return othery + otherh;
								case "center": return othery + otherh / 2;
								default:return othery;
							}
						}
					}
				}
		}
		return 0;
	}
	
	private function calcMaxMinSize(data:Fast,width:Dynamic=null,height:Dynamic=null):{min_width:Float,min_height:Float,max_width:Float,max_height:Float}{
		var min_w:Float = 0;
		var min_h:Float = 0;
		var max_w:Float = Math.POSITIVE_INFINITY;
		var max_h:Float = Math.POSITIVE_INFINITY;
		var temp_min_w:Float = 0;
		var temp_min_h:Float = 0;
		var temp_max_w:Float = Math.POSITIVE_INFINITY;
		var temp_max_h:Float = Math.POSITIVE_INFINITY;
		
		if (data.hasNode.exact_size) {
			for (exactNode in data.nodes.exact_size) {
				var exact_w_str:String = U.xml_str(exactNode.x, "width");
				var exact_h_str:String = U.xml_str(exactNode.x, "height");
				min_w = _getDataSize("w", exact_w_str, 0);
				min_h = _getDataSize("h", exact_h_str, 0);
				max_w = min_w;
				max_h = min_h;
			}
		}else{		
			if (data.hasNode.min_size) {
				for(minNode in data.nodes.min_size){
					var min_w_str:String = U.xml_str(minNode.x, "width");
					var min_h_str:String = U.xml_str(minNode.x, "height");
					temp_min_w = _getDataSize("w", min_w_str, 0);
					temp_min_h = _getDataSize("h", min_h_str, 0);			
					if (temp_min_w > min_w) {
						min_w = temp_min_w;
					}
					if (temp_min_h > min_h) {
						min_h = temp_min_h;
					}
				}
			}
			
			if (data.hasNode.max_size) {
				for(maxNode in data.nodes.max_size){
					var max_w_str:String = U.xml_str(maxNode.x, "width");
					var max_h_str:String = U.xml_str(maxNode.x, "height");
					temp_max_w = _getDataSize("w", max_w_str, Math.POSITIVE_INFINITY);
					temp_max_h = _getDataSize("h", max_h_str, Math.POSITIVE_INFINITY);			
					if (temp_max_w < max_w) {
						max_w = temp_max_w;
					}
					if (temp_max_h < max_h) {
						max_h = temp_max_h;
					}
				}
			}
		}
		
		if (width != null){
			if (width > min_w) { min_w = width; }			
			if (width < max_w) { max_w = width; }
		}
		if (height != null) {
			if (height > min_h) { min_h = height; }
			if (height < max_h) { max_h = height; }
		}
		
		//don't go below 0 folks:
		
		if (max_w <= 0) { max_w = Math.POSITIVE_INFINITY; }
		if (max_h <= 0) { max_h = Math.POSITIVE_INFINITY; }
		
		return { min_width:min_w, min_height:min_h, max_width:max_w, max_height:max_h };
	}
	
	/**********************/
	
	private function _getDataSize(target:String, str:String,default_:Float=0):Float {
		var result: { percent:Float, error:Bool } = U.perc_to_float(str);
		var percf:Float = result.percent;
		if(!result.error){
			switch(target) {
				case "w", "width":	return thisWidth() * percf;
					
				case "h", "height": return thisHeight() * percf;
			}
		}else {
			if (str.indexOf("stretch:") == 0) {
				str = StringTools.replace(str, "stretch:", "");
				var arr:Array<String> = str.split(",");
				var stretch_0:Float = _getStretch(0, target, arr[0]);
				var stretch_1:Float = _getStretch(1, target, arr[1]);
				if(stretch_0 != -1 && stretch_1 != -1){
					return stretch_1 - stretch_0;
				}else {
					return default_;
				}
			}else if (str.indexOf("asset:") == 0) {
				str = StringTools.replace(str, "asset:", "");
				var assetValue:Float = _getStretch(1, target, str);
				return assetValue;				
			}else if(U.isStrNum(str)){
				return Std.parseFloat(str);
			}else {
				var r:EReg = ~/[\w]+\.[\w]+/;
				if (r.match(str)) {
					var assetValue:Float = _getStretch(1, target, str);
					return assetValue;
				}					
			}
		}
		return default_;
	}
	
	/**
	 * Give me a string like "thing.right+10" and I'll return ["+",10]
	 * Only accepts one operator and operand at max!
	 * The operand MUST be a number.
	 * @param	string of format: <value><operator><operand>
	 * @return [<value>:String,<operator>:String,<operand>:Float]
	 */
	
	private function _getOperation(str:String):Array<Dynamic> {
		var list:Array<String> = ["+", "-", "*", "/", "^"];
		var temp:Array<String> = null;
		
		for (operator in list) {
			if (str.indexOf(operator) != -1) {		//return on the FIRST valid operator match found
				temp = str.split(operator);			
				if (temp != null && temp.length == 2) {		//if I find exactly one operator/operand
					var f:Float = Std.parseFloat(temp[1]);	//try to read the operand as a number
					if (f == 0 && temp[1] != "0") {
						return null;	//improperly formatted, invalid operand, bail out
					}else{
						return [temp[0], operator, f];	//proper operand and operator
					}
				}
			}
		}
		
		return null;
	}
	
	private function _doOperation(value:Float, operator:String, operand:Float):Float {
		switch(operator) {
			case "+": return value + operand;
			case "-": return value - operand;
			case "/": return value / operand;
			case "*": return value * operand;
			case "^": return Math.pow(value, operand);
		}
		return value;
	}
	
	private function _getStretch(index:Int, target:String, str:String):Float {
		var arr:Array<Dynamic> = null;
		var prop:String = "";
		var operator:String = "";
		var operand:Float = 0;
		
		arr = _getOperation(str);
		if (arr != null) {
			str = cast arr[0];
			operator = cast arr[1];
			operand = cast arr[2];
		}
		
		if (str.indexOf(".") != -1) {
			arr = str.split(".");
			str = arr[0];
			prop = arr[1];			
		}
		
		var flxb:FlxBasic = getAsset(str);		
		var other:FlxObject = null;
		var other_width:Float = 0;
		var other_height:Float = 0;
		var other_x:Float = 0;
		var other_y:Float = 0;
		if (Std.is(flxb, FlxObject)) {
			other = cast flxb;			
			other_width = other.width;
			other_height = other.height;
			other_x = other.x;
			other_y = other.y;
		}
		
		var return_val:Float = 0;
		
		if (other == null) {			
			switch(str) {
				case "top", "up": return_val = 0;
				case "bottom", "down": return_val = thisHeight();
				case "left": return_val = 0;
				case "right": return_val = thisWidth();				
				default:
					if (U.isStrNum(str)) {
						return_val = Std.parseFloat(str);
					}else {
						return_val = -1;
					}
			}
		}else {
			switch(target) {
				case "w", "width": 
					if(prop == ""){
						if (index == 0) { return_val = other_x + other_width; }
						if (index == 1) { return_val = other_x; }
					}else {
						switch(prop) {
							case "right": return_val = other_x + other_width;
							case "left": return_val = other_x;
							case "center": return_val = other_x + (other_width / 2);
							case "width": return_val = other_width;
						}
					}
				case "h", "height":
					if(prop == ""){
						if (index == 0) { return_val = other_y + other_height; }
						if (index == 1) { return_val = other_y; }
					}else {
						switch(prop){
							case "top", "up": return_val = other_y;
							case "bottom", "down": return_val = other_y +other_height;
							case "center": return_val = other_y + (other_height / 2);
							case "height": return_val = other_height;
						}
					}
			}
		}
		
		if (return_val != -1 && operator != "") {
			return_val = _doOperation(return_val, operator, operand);
		}
		
		return return_val;
	}
	
	private function _loadPosition(data:Fast, thing:Dynamic):Void {
		var X:Float = U.xml_f(data.x, "x");				//position offset from 0,0
		var Y:Float = U.xml_f(data.x, "y");
		var ctrX:Bool = U.xml_bool(data.x, "center_x");	//if true, centers on the screen
		var ctrY:Bool = U.xml_bool(data.x, "center_y");
				
		var center_on:String = U.xml_str(data.x, "center_on");
		var center_on_x:String = U.xml_str(data.x, "center_on_x");
		var center_on_y:String = U.xml_str(data.x, "center_on_y");
		
		var anchor_x_str:String = "";
		var anchor_y_str:String = "";
		var anchor_x:Float = 0;
		var anchor_y:Float = 0;
		var anchor_x_flush:String = "";
		var anchor_y_flush:String = "";
		
		if (data.hasNode.anchor) {
			anchor_x_str = U.xml_str(data.node.anchor.x, "x");
			anchor_y_str = U.xml_str(data.node.anchor.x, "y");
						
			anchor_x = _getAnchorPos(thing, "x", anchor_x_str);
			anchor_y = _getAnchorPos(thing, "y", anchor_y_str);
			anchor_x_flush = U.xml_str(data.node.anchor.x, "x-flush",true);
			anchor_y_flush = U.xml_str(data.node.anchor.x, "y-flush", true);						
		}
				
		//Flush it to the anchored coordinate
		if (anchor_x_str != "" || anchor_y_str != "") {
			switch(anchor_x_flush) {
				case "left":	//do-nothing		 					//flush left side to anchor
				case "right":	anchor_x = anchor_x - thing.width;	 	//flush right side to anchor
				case "center":  anchor_x = anchor_x - thing.width / 2;	//center on anchor point
			}
			switch(anchor_y_flush) {
				case "up", "top": //do-nothing
				case "down", "bottom": anchor_y = anchor_y - thing.height;
				case "center": anchor_y = anchor_y - thing.height / 2;
			}
			
			_delta(thing, anchor_x, anchor_y);
		}
		
		//Try to center the object on the screen:
		if (ctrX || ctrY) {
			_center(thing,ctrX,ctrY);
		}
				
		//Then, try to center it on another object:
		if (center_on != "") {
			var other:FlxBasic = getAsset(center_on);
			if (other != null && Std.is(other, FlxBasic)) {
				U.center(cast(other, FlxObject), cast(thing, FlxObject));
			}
		}else {
			if (center_on_x != "") {
				var other:FlxBasic = getAsset(center_on);
				if (other != null && Std.is(other, FlxBasic)) {
					U.center(cast(other, FlxObject), cast(thing, FlxObject), true, false);
				}
			}
			if (center_on_y != "") {
				var other:FlxBasic = getAsset(center_on);
				if (other != null && Std.is(other, FlxBasic)) {
					U.center(cast(other, FlxObject), cast(thing, FlxObject), false, true);
				}
			}
		}
		
		//Then, add its offset to wherever it wound up:
		_delta(thing, X, Y);
	}	
	
	private function _loadColor(data:Fast,_default:Int=0xffffffff):Int {
		var colorStr:String = U.xml_str(data.x, "color");
		if (colorStr == "" && data.x.nodeName == "color") { 
			colorStr = U.xml_str(data.x, "value"); 
		}
		var color:Int = _default;		
		if (colorStr != "") { color = U.parseHex(colorStr, true); }		
		return color;
	}
	
	private function _loadFontFace(data:Fast):String{
		var fontFace:String = U.xml_str(data.x, "font"); 
		var fontStyle:String = U.xml_str(data.x, "style");
		var the_font:String = null;
		if (fontFace != "") { the_font = U.font(fontFace, fontStyle); }
		
		return the_font;
	}
	
	private function _onFinishLoad():Void {
		if (_ptr != null) {
			_ptr.getEvent("finish_load", this, null);
		}
	}
	
	private function _onClickRadioGroup(params:Dynamic = null):Void {
		FlxG.log.add("FlxUI._onClickRadioGroup(" + params + ")");
		if (_ptr != null) {
			_ptr.getEvent("click_radio_group", this, params);
		}	
	}
	
	private function _onClickCheckBox(params:Dynamic = null):Void {
		FlxG.log.add("FlxUI._onClickCheckBox(" + params + ")");
		if (_ptr != null) {
			_ptr.getEvent("click_checkbox", this, params);
		}		
	}
	
	private function _onClickButton(params:Array<Dynamic> = null):Void {
		FlxG.log.add("FlxUI._onClickButton(" + params + ")");
		if (_ptr != null) {
			_ptr.getEvent("click_button", this, params);
		}
	}
	
	private function _onClickButtonToggle(params:Dynamic = null):Void {
		FlxG.log.add("FlxUI._onClickButtonToggle(" + params + ")");
		if (_ptr != null) {
			_ptr.getEvent("click_button_toggle", this, params);
		}
	}
	
	/**********UTILITY FUNCTIONS************/
	
	private function getText(flag:String, context:String = "data", safe:Bool = true):String {
		if(_ptr_tongue != null){
			return _ptr_tongue.get(flag, context, safe);
		}
		return flag;
	}
	
	/**
	 * Parses params out of xml and loads them in the correct type
	 * @param	data
	 */
	
	private static inline function getParams(data:Fast):Array<Dynamic>{
		var params:Array<Dynamic> = null;
		if (data.hasNode.param) {
			params = new Array<Dynamic>();
			for (param in data.nodes.param) {
				if(param.has.type && param.has.value){
					var type:String = param.att.type;
					type = type.toLowerCase();
					switch(type) {
						case "string": params.push(new String(param.att.value));
						case "int": params.push(Std.parseInt(param.att.value));
						case "float": params.push(Std.parseFloat(param.att.value));
						case "color", "hex":params.push(U.parseHex(param.att.value, true));
					}
				}
			}
		}
		return params;
	}	
			
	private function formatButtonText(data:Fast, button:Dynamic):Void {
		if (data != null && data.hasNode.text) {
			var textNode = data.node.text;
			var use_def:String = U.xml_str(textNode.x, "use_def", true);
			var text_def:Fast = textNode;
			
			if (use_def != "") {
				text_def = getDefinition(use_def);
			}			
			
			var text_data:Fast = textNode;
			if (text_def != null) { text_data = text_def; };
							
			var case_id:String = U.xml_str(textNode.x, "id", true);
			var the_font:String = _loadFontFace(text_data);
			var size:Int = U.xml_i(text_data.x, "size"); if (size == 0) { size = 8;}
			var color:Int = _loadColor(text_data);				
							
			var shadow:Int = U.xml_i(text_data.x, "shadow");
			var dropShadow:Bool = U.xml_bool(text_data.x, "dropShadow");
			var align:String = U.xml_str(text_data.x, "align", true); if (align == "") { align = null;}
			
			var the_label:FlxText=null;
			var fb:FlxUIButton = null;
			var cb:FlxUICheckBox = null;
			
			if (Std.is(button, FlxUIButton)) {
				fb = cast button;
				if (align == "" || align == null) {
					align = "center";
				}
			}else if (Std.is(button, FlxUICheckBox)) {
				var cb:FlxUICheckBox = cast button;
				fb = cb.button;				
				align = "left";			//force this for check boxes
			}
			
			the_label = fb.label;
			fb.up_color = color;
			fb.down_color = 0;
			fb.over_color = 0;				
			
			if (the_label != null) {
				the_label.setFormat(the_font, size, color, align, shadow,shadow!=0);
				
				//TODO: text.dropShadow = true;		
				
				if (Std.is(the_label, FlxUIText)) {
					var ftu:FlxUIText = cast the_label;
					ftu.forceCalcFrame();
				}
			}	
			
			for (textColorNode in textNode.nodes.color) {
				var color:Int = _loadColor(textColorNode);
				var state_id:String = U.xml_str(textColorNode.x, "id", true);
				var toggle:Bool = U.xml_bool(textColorNode.x, "toggle");				
				switch(state_id) {
					case "up", "inactive", "", "up", "normal": 
						if (!toggle) {
							fb.up_color = color; 
						}else {
							fb.up_toggle_color = color;
						}							
					case "active", "hilight", "over", "hover": 
						if(!toggle){
							fb.over_color = color; 
						}else {
							fb.over_toggle_color = color;
						}
					case "down", "pressed", "pushed": 
						if(!toggle){
							fb.down_color = color; 
						}else {
							fb.down_toggle_color = color;
						}
				}				
			}
			
			if (fb.over_color == 0) {			//if no over color, match up color
				fb.over_color = fb.up_color;
			}
			if (fb.down_color == 0) {			//if no down color, match over color
				fb.down_color = fb.over_color;
			}
				
			//if toggles are undefined, match them to the normal versions
			if (fb.up_toggle_color == 0) {			
				fb.up_toggle_color = fb.up_color;
			}
			if (fb.over_toggle_color == 0) {
				fb.over_toggle_color = fb.over_color;
			}
			if (fb.down_toggle_color == 0) {
				fb.down_toggle_color = fb.down_color;
			}
		}
	}

}