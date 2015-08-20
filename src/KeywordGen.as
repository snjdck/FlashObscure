package
{
	import flash.display.Sprite;
	import flash.reflection.getTypeInfo;
	import flash.reflection.typeinfo.TypeInfo;
	import flash.utils.getDefinitionByName;
	
	import array.pushIfNotHas;
	
	public class KeywordGen extends Sprite
	{
//		[Embed(source="catalog.xml", mimeType="application/octet-stream")]
		public var Bin:Class;
		
		public function KeywordGen()
		{
			var str:String = new Bin().toString();
			var xml:XML = XML(str);
			var ns:Namespace = xml.namespace();
			var list:XMLList = xml.ns::libraries.ns::library.ns::script.ns::def;
			var nameList:Array = [];
			for each(var item:XML in list){
				nameList.push(item.@id.toString());
			}
			for each(var symbol:String in nameList){
				try{
					var type:* = getDefinitionByName(symbol.replace(":", "::"));
				}catch(e:Error){
					addToBlack(symbol, otherSet);
					continue;
				}
				if(type is Function){
					addToBlack(symbol, funcNameSet);
				}else if(type is Class){
					addToBlack(symbol, clsNameSet);
					var typeInfo:TypeInfo = getTypeInfo(type);
					var key:String;
					for(key in typeInfo.staticVariables){
						pushIfNotHas(propNameSet, key);
					}
					for(key in typeInfo.staticMethods){
						pushIfNotHas(propNameSet, key);
					}
					for(key in typeInfo.variables){
						pushIfNotHas(propNameSet, key);
					}
					for(key in typeInfo.methods){
						pushIfNotHas(propNameSet, key);
					}
				}else{
					addToBlack(symbol, otherSet);
				}
			}
			packageSet.sort();
			otherSet.sort();
			funcNameSet.sort();
			clsNameSet.sort();
			propNameSet.sort();
			trace(packageSet.join("\n"));
			trace("=========================", packageSet.length);
			trace(otherSet.join("\n"));
			trace("=========================", otherSet.length);
			trace(funcNameSet.join("\n"));
			trace("=========================", funcNameSet.length);
			trace(clsNameSet.join("\n"));
			trace("=========================", clsNameSet.length);
			trace(propNameSet.join("\n"));
			trace("=========================", propNameSet.length);
		}
		
		private var packageSet:Array = [];
		private var otherSet:Array = [];
		private var funcNameSet:Array = [];
		private var clsNameSet:Array = [];
		private var propNameSet:Array = [];
		
		private function addToBlack(str:String, output:Array):void
		{
			var index:int = str.lastIndexOf(":");
			if(index >= 0){
				pushIfNotHas(packageSet, str.slice(0, index));
				pushIfNotHas(output, str.slice(index+1));
			}else{
				pushIfNotHas(output, str);
			}
		}
	}
}