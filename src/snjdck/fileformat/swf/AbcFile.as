package snjdck.fileformat.swf
{
	import flash.utils.ByteArray;
	
	import array.pushIfNotHas;
	
	import lambda.callTimes;
	
	import snjdck.fileformat.abc.StringSet;
	import snjdck.fileformat.abc.enum.Constants;
	import snjdck.fileformat.abc.io.Reader;
	import snjdck.fileformat.swf.utils.RawDict;
	
	import stdlib.constant.CharSet;

	/**
	 * black:class or instance var default value
	 * white:trait
	 */
	final public class AbcFile
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
			callTimes(clsCount, readInstanceInfo);
			callTimes(clsCount, readMethodIndexAndTrait);//ClassInfo
			skip(readMethodIndexAndTrait);//ScriptInfo
			skip(readMethodBodyInfo);
		}
		
		private function readString():void
		{
			var numChar:int = reader.readS32();
			shaokai.push([source.position, numChar]);
			strList.push(source.readUTFBytes(numChar));
		}
		
		private function readNamespace():void
		{
			nsList.push([source.readUnsignedByte(), reader.readS32()]);//ns type(private,public), utf_index
		}
		
		private function readMultiName():void
		{
			var multiName:Array;
			switch(source.readUnsignedByte()){
				case Constants.CONSTANT_Qname:
				case Constants.CONSTANT_QnameA://ns + utf_name
					multiName = [reader.readS32(), reader.readS32()];
					break;
				case Constants.CONSTANT_Multiname:
				case Constants.CONSTANT_MultinameA://utf_name + ns_set
					reader.readS32();
					reader.readS32();
					break;
				case Constants.CONSTANT_RTQname:
				case Constants.CONSTANT_RTQnameA:
					reader.readS32();//utf_name
					break;
				case Constants.CONSTANT_MultinameL:
				case Constants.CONSTANT_MultinameLA:
					reader.readS32();//ns_set
					break;
				case Constants.CONSTANT_TypeName:
					reader.readS32();
					reader.readS32List();
					break;
				case Constants.CONSTANT_RTQnameL:
				case Constants.CONSTANT_RTQnameLA:
					break;
			}
			multiNameList.push(multiName);
		}
		/*
		private function printMultiName(index:int):void
		{
			var info:Array = multiNameList[index];
			if(null == info){
				trace("no multi name");
				return;
			}
			var ns:Array = nsList[info[0]];
			
			trace("++++++++++++++++++++++++++++++++++++++++",ns[0],strIndexBlackList.getValue(ns[1]),strIndexBlackList.getValue(info[1]));
		}
		//*/
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
			reader.readExceptionList();
			skip(readTraitInfo);
		}
		
		private function readTraitInfo():void
		{
			const multiNameIndex:int = reader.readS32();
			const kind:uint = source.readUnsignedByte();
			reader.readS32();//slot_id
			reader.readS32();//propTypeIndex
			switch(kind & 0xF){
				case Constants.TRAIT_Slot:
				case Constants.TRAIT_Const:
					var valueIndex:int = reader.readS32();
					if(valueIndex != 0){
						reader.readDefaultParam(valueIndex);
					}
			}
			if(kind & 0x40){//metadata
				reader.readS32List();
			}
			addMultiNameToWhiteList(multiNameIndex);
		}
		
		private function skip(handler:Function, flag:int=0):void
		{
			var count:uint = reader.readS32();
			while(count-- > flag){
				handler();
			}
		}
		
		public function collect(all:Array, white:Array, black:Array):void
		{
			for each(var str:String in strList){
				pushIfNotHas(all, str);
			}
			var strIndex:int;
			for each(strIndex in strIndexWhiteList.indexList){
				pushIfNotHas(white, strList[strIndex]);
			}
			for each(strIndex in strIndexBlackList.indexList){
				pushIfNotHas(black, strList[strIndex]);
			}
		}
		
		public function mixCode(nameDict:RawDict):void
		{
			for(var strIndex:int=strList.length-1; strIndex > 0; --strIndex)
			{
				var mixedStr:String = nameDict.getValue(strList[strIndex]);
				if(null == mixedStr){
					continue;
				}
				var start:int = shaokai[strIndex][0];
				var nChar:int = shaokai[strIndex][1];
				source.position = start;
				source.writeMultiByte(mixedStr, CharSet.ASCII);
				assert(source.position <= start + nChar, strList[strIndex]);
			}
		}
		
		private function addMultiNameToWhiteList(nameIndex:int):void
		{
			var info:Array = multiNameList[nameIndex];
			var ns:Array = nsList[info[0]];
			strIndexWhiteList.addIndex(ns[1]);
			strIndexWhiteList.addIndex(info[1]);
		}
	}
}