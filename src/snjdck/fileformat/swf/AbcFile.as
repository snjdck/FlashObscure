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
			
			skip(readInt, 1);//int
			skip(readInt, 1);//uint
			skip(reader.readDouble, 1);//double
			skip(readString, 1);//string
			skip(readNamespace, 1);//namespace
			skip(reader.readS32List, 1);//ns_set
			skip(readMultiName, 1);//mulity name
			skip(reader.readMethodInfo);
			skip(reader.readMetadataInfo);
			const clsCount:int = readInt();
			callTimes(clsCount, readInstanceInfo);
			callTimes(clsCount, readMethodIndexAndTrait);//ClassInfo
			skip(readMethodIndexAndTrait);//ScriptInfo
			skip(readMethodBodyInfo);
			
			assert(source.bytesAvailable == 0, "parse abc error!");
		}
		
		private function readString():void
		{
			var numChar:uint = readInt();
			shaokai.push([source.position, numChar]);
			strList.push(source.readUTFBytes(numChar));
		}
		
		private function readNamespace():void
		{
			nsList.push([source.readUnsignedByte(), readInt()]);
		}
		
		private function readMultiName():void
		{
			var multiName:Array;
			switch(source.readUnsignedByte()){
				case 0x07: case 0x0D://ns + name
					multiName = [readInt(), readInt()];
					break;
				case 0x11: case 0x12:
					break;
				case 0x09: case 0x0E://name + ns_set
					readInt();
					readInt();
					break;
				case 0x0F: case 0x10:
					readInt();//name
					break;
				case 0x1B: case 0x1C:
					readInt();//ns_set
					break;
				case 0x1D:
					readInt();
					reader.readS32List();
					break;
				default:
					throw new Error("unknow kind!");
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
			addMultiNameToWhiteList(reader.readS32());//class name or interface name
			reader.readS32();//super multi name
			if(source.readUnsignedByte() & 0x08){
				addNotParsedStrIndex(nsList[readInt()][1], ":");//protected namespace
			}
			reader.readS32List();//接口
			readMethodIndexAndTrait();
		}
		
		private function readMethodIndexAndTrait():void
		{
			//it can be a instance constructor, class static initializer or script initializer.
			readInt();//method index
			skip(readTraitInfo);
		}
		
		private function readMethodBodyInfo():void
		{
			readInt();//method index
			callTimes(4, readInt);
			reader.readInstructionList();
			skip(reader.readExceptionInfo);
			skip(readTraitInfo);
		}
		
		private function readTraitInfo():void
		{
			const multiNameIndex:uint = readInt();
			const kind:uint = source.readUnsignedByte();
			switch(kind & 0xF){
				case Constants.TRAIT_Slot:
				case Constants.TRAIT_Const:
					readInt();//slot_id
					readInt();//属性类型
					if(readInt() != 0){
						source.readUnsignedByte();
					}
					addMultiNameToWhiteList(multiNameIndex);
					break;
				case 1: case 5: case 2: case 3://method, function, getter, setter
					addMultiNameToWhiteList(multiNameIndex);
					readInt();
					readInt();//method array
					break;
				case Constants.TRAIT_Class://class
					readInt();
					readInt();//class array
					break;
				default:
					throw new Error("kind error!");
			}
			
			if(kind & 0x40){
				reader.readS32List();
			}
		}
		
		private function skip(handler:Function, flag:int=0):void
		{
			var count:uint = readInt();
			while(count-- > flag){
				handler();
			}
		}
		
		private function readInt():uint
		{
			return Reader.ReadS32(source);
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