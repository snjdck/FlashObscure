package snjdck.fileformat.swf
{
	import flash.utils.ByteArray;
	
	import array.pushIfNotHas;
	
	import lambda.callTimes;
	
	import snjdck.fileformat.abc.StringSet;
	import snjdck.fileformat.abc.enum.Constants;
	import snjdck.fileformat.abc.io.Reader;

	internal class AbcFile
	{
		private const strList:Array = ["*"];
		private const nsList:Array = [null];
		private const multiNameList:Array = [null];
		private const shaokai:Array = [null];
		
		private var strIndexWhiteList:StringSet;//需要混淆的str index
		private var strIndexBlackList:StringSet;//不能混淆的str index
		
		private var source:ByteArray;
		private var reader:Reader;
		
		public function AbcFile(bin:ByteArray)
		{
			source = bin;
			strIndexWhiteList = new StringSet(strList);
			strIndexBlackList = new StringSet(strList);
			reader = new Reader(bin, strIndexBlackList, strIndexWhiteList);
			init();
		}
		
		private function init():void
		{
			source.position += 4;//version
			
			skip(reader.readS32, 1);//int
			skip(reader.readS32, 1);//uint
			skip(reader.readDouble, 1);//double
			skip(readString, 1);//string
			skip(readNamespace, 1);//namespace
			skip(reader.readS32List, 1);//ns_set
			skip(readMultiName, 1);//mulity name
			skip(reader.readMethodInfo);
			skip(reader.readMetadataInfo);
			const clsCount:int = reader.readS32();
			trace("---------readInstanceInfo");
			callTimes(clsCount, readInstanceInfo);
			trace("---------readClassInfo");
			callTimes(clsCount, readMethodIndexAndTrait);//ClassInfo
			trace("---------readScriptInfo");
			skip(readMethodIndexAndTrait);//ScriptInfo
			trace("---------readMethodBodyInfo");
			skip(readMethodBodyInfo);
			
			assert(source.bytesAvailable == 0, "parse abc error!");
		}
		
		private function readString():void
		{
			var numChar:uint = reader.readS32();
			shaokai.push([source.position, numChar]);
			strList.push(source.readUTFBytes(numChar));
		}
		
		private function readNamespace():void
		{
			nsList.push([source.readUnsignedByte(), reader.readS32()]);
		}
		
		private function readMultiName():void
		{
			var multiName:Array;
			switch(source.readUnsignedByte()){
				case Constants.CONSTANT_Qname:
				case Constants.CONSTANT_QnameA://ns + utf_name
					multiName = [readInt(), readInt()];
					break;
				case Constants.CONSTANT_Multiname:
				case Constants.CONSTANT_MultinameA://utf_name + ns_set
					readInt();
					readInt();
					break;
				case Constants.CONSTANT_RTQname:
				case Constants.CONSTANT_RTQnameA:
					readInt();//utf_name
					break;
				case Constants.CONSTANT_MultinameL:
				case Constants.CONSTANT_MultinameLA:
					readInt();//ns_set
					break;
				case Constants.CONSTANT_TypeName:
					readInt();
					reader.readS32List();
					break;
				case Constants.CONSTANT_RTQnameL:
				case Constants.CONSTANT_RTQnameLA:
					break;
			}
			multiNameList.push(multiName);
		}
		
		private function printMultiName(index:int):void
		{
			var info:Array = multiNameList[index];
			var ns:Array = nsList[info[0]];
			
			trace("++++++++++++++++++++++++++++++++++++++++",ns[0],strIndexBlackList.getValue(ns[1]),strIndexBlackList.getValue(info[1]));
		}
		
		private function readInstanceInfo():void
		{
			reader.readS32();//class or interface multi name
			reader.readS32();//super multi name
			if(source.readUnsignedByte() & Constants.CLASS_FLAG_protected){
				reader.readS32();//ns index
			}
			reader.readS32List();//接口
			readMethodIndexAndTrait();
		}
		
		private function readMethodIndexAndTrait():void
		{
			//it can be a instance constructor, class static initializer or script initializer.
			reader.readS32();//method index
			skip(readTraitInfo);
		}
		
		private function readMethodBodyInfo():void
		{
			callTimes(5, reader.readS32);
			reader.readInstructionList();
			skip(readExceptionInfo);
			skip(readTraitInfo);
		}
		
		private function readExceptionInfo():void{
			callTimes(4, reader.readS32);
			addMultiNameToWhiteList(reader.readS32());
		}
		
		private function readTraitInfo():void
		{
			const multiNameIndex:uint = readInt();
			const kind:uint = source.readUnsignedByte();
			
			switch(kind & 0xF){
				case Constants.TRAIT_Slot:
				case Constants.TRAIT_Const:
					reader.readS32();//slot_id
					reader.readS32();//属性类型
					var valueIndex:int = reader.readS32();
					if(valueIndex != 0){
						var valueType:int = source.readUnsignedByte();
						if(valueType == Constants.CONSTANT_Utf8){
							strIndexBlackList.addIndex(valueIndex);
						}
					}
					break;
				case Constants.TRAIT_Method:
				case Constants.TRAIT_Getter:
				case Constants.TRAIT_Setter:
				case Constants.TRAIT_Function:
				case Constants.TRAIT_Class:
					reader.readS32();
					reader.readS32();
					break;
			}
			addMultiNameToWhiteList(multiNameIndex);
//			printMultiName(multiNameIndex);
//			trace(kind & 0xf, "***************************************************");
			
			if((kind >> 4) & Constants.ATTR_metadata){
				reader.readS32List();
			}
		}
		
		private function skip(handler:Function, flag:int=0):void
		{
			var count:uint = reader.readS32();
			while(count-- > flag){
				handler();
			}
		}
		
		private function readInt():uint
		{
			return reader.readS32();
		}
		
		public function collect(all:Array, white:Array, black:Array):void
		{
			var strIndex:uint;
			var str:String;
			for each(str in strList){
				pushIfNotHas(all, str);
			}
			for each(strIndex in strIndexWhiteList.indexList){
				pushIfNotHas(white, strList[strIndex]);
			}
			for each(strIndex in strIndexBlackList.indexList){
				pushIfNotHas(black, strList[strIndex]);
			}
		}
		
		public function mixCode(nameDict:Object):void
		{
			var count:int = strList.length;
			for(var strIndex:int=0; strIndex<count; ++strIndex){
				var str:String = strList[strIndex];
				var mixedStr:String = nameDict[str];
				if(mixedStr != null){
					mixStr(strIndex, mixedStr);
				}
			}
		}
		
		private function mixStr(strIndex:uint, mixedStr:String):void
		{
			source.position = shaokai[strIndex][0];
			//var nChar:int = shaokai[strIndex][1];
			source.writeUTFBytes(mixedStr);
		}
		
		private function addMultiNameToWhiteList(nameIndex:int):void
		{
			var info:Array = multiNameList[nameIndex];
			var ns:Array = nsList[info[0]];
			strIndexWhiteList.addIndex(ns[1]);
			strIndexWhiteList.addIndex(info[1]);
		}
		
		private function addNotParsedStrIndex(strIndex:uint, flag:String):void
		{
			var str:String = strList[strIndex];
			var index:int = str.lastIndexOf(flag);
			if(index != -1){
				strIndexBlackList.addStr(str.slice(0, index));
				strIndexBlackList.addStr(str.slice(index+1));
			}
			strIndexBlackList.addIndex(strIndex);
		}
	}
}