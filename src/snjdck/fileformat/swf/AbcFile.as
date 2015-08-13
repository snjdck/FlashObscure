package snjdck.fileformat.swf
{
	import flash.utils.ByteArray;
	
	import array.pushIfNotHas;
	
	import lambda.callTimes;
	
	import snjdck.fileformat.abc.Instruction;
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
			reader = new Reader(bin);
			strIndexWhiteList = new StringSet(strList);
			strIndexBlackList = new StringSet(strList);
			init();
		}
		
		private function init():void
		{
			source.position += 4;//version
			
			skip(readInt, 1);//int
			skip(readInt, 1);//uint
			skip(reader.readDouble, 1);//double
			skip(readString, 1);//string
			skip(function():void{
				nsList.push([source.readUnsignedByte(), readInt()]);
			}, 1);//namespace
			skip(function():void{
				skip(readInt);
			}, 1);//ns_set
			skip(readMultiName, 1);//mulity name
			skip(readMethodInfo);
			skip(readMetadataInfo);
			const clsCount:uint = readInt();
			callTimes(clsCount, readInstanceInfo);
			callTimes(clsCount, readClassInfo);
			skip(readScriptInfo);
			skip(readMethodBodyInfo);
			
			if(source.bytesAvailable > 0){
				throw new Error("AbcFile not read to end");
			}
			/*
			ArrayUtil.Append(aaa, strList);
			++a;
			
			if(a == 393){
				aaa = ArrayUtil.Unique(aaa);
				trace(aaa.length);
				var ba:ByteArray = new ByteArray();
				for each(var str:String in aaa){
					ba.writeUTF(str);
				}
				ba.compress(CompressionAlgorithm.LZMA);
				DeCom.file.save(ba);
			}
			//*/
		}
		
		private function readString():void
		{
			var numChar:uint = readInt();
			shaokai.push([source.position, numChar]);
			strList.push(source.readUTFBytes(numChar));
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
					skip(readInt);
					break;
				default:
					throw new Error("unknow kind!");
			}
			multiNameList.push(multiName);
		}
		
		private function readMethodInfo():void
		{
			const param_count:uint = readInt();
			readInt();//return type
			callTimes(param_count, readInt);//paramType
			readInt();//name
			const flags:uint = source.readUnsignedByte();
			if(flags & Constants.HAS_OPTIONAL){//参数默认值
				skip(reader.readDefaultParam);
			}
			if(flags & Constants.HAS_ParamNames){//参数名称
				callTimes(param_count, readInt);
			}
		}
		
		private function readMetadataInfo():void
		{
			readInt();//tagName
			skip(reader.readTwoS32);//key,value
		}
		
		private function readInstanceInfo():void
		{
			readInt();//multiNameIndex
			readInt();//super name
			if(source.readUnsignedByte() & 0x08){
				addNotParsedStrIndex(nsList[readInt()][1], ":");//protected namespace
			}
			skip(readInt);//接口
			//This is an index into the method array of the abcFile;
			//it references the method that is invoked whenever an object of this class is constructed.
			//This method is sometimes referred to as an instance initializer.
			readInt();
			skip(readTraitInfo);
		}
		
		private function readClassInfo():void
		{
			//This is an index into the method array of the abcFile;
			//it references the method that is invoked when the class is first created.
			//This method is also known as the static initializer for the class.
			readInt();
			skip(readTraitInfo);
		}
		
		private function readScriptInfo():void
		{
			//The init field is an index into the method array of the abcFile.
			//It identifies a function that is to be invoked prior to any other code in this script.
			readInt();
			skip(readTraitInfo);
		}
		
		private function readMethodBodyInfo():void
		{
			//The method field is an index into the method array of the abcFile;
			//it identifies the method signature with which this body is to be associated.
			readInt();
			callTimes(4, readInt);
			readInstructionInfo(readInt() + source.position);
			skip(readExceptionInfo);
			skip(readTraitInfo);
		}
		
		private function readExceptionInfo():void{
			callTimes(5, readInt);
		}
		
		private function readTraitInfo():void
		{
			const multiNameIndex:uint = readInt();
			const kind:uint = source.readUnsignedByte();
			switch(kind & 0xF){
				case 0: case 6://slot, const
					readInt();//slot_id
					readInt();//属性类型
					if(readInt() != 0){
						source.readUnsignedByte();
					}
					addPropName(multiNameIndex);
					break;
				case 1: case 5: case 2: case 3://method, function, getter, setter
					addPropName(multiNameIndex);
					readInt();
					readInt();//method array
					break;
				case 4://class
					addClassName(multiNameIndex);
					readInt();
					readInt();//class array
					break;
				default:
					throw new Error("kind error!");
			}
			
			if(kind & 0x40){
				skip(readInt);
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
		
		private function addClassName(nameIndex:int):void
		{
			var info:Array = multiNameList[nameIndex];
			var ns:Array = nsList[info[0]];
			
			switch(ns[0]){
				case 0x05://包外类
					strIndexWhiteList.addIndex(info[1]);
					break;
				case 0x16://public class
				case 0x17://internal class
					strIndexWhiteList.addIndex(ns[1]);
					strIndexWhiteList.addIndex(info[1]);
					break;
			}
		}
		
		private function addPropName(nameIndex:int):void
		{
			var info:Array = multiNameList[nameIndex];
			var ns:Array = nsList[info[0]];
			
			strIndexWhiteList.addIndex(ns[1]);
			strIndexWhiteList.addIndex(info[1]);
			/*
			switch(ns[0]){
				case 0x16://public
				case 0x08://接口,native类方法
				case 0x17://internal
				case 0x18://protected
				case 0x1A://static protected
				case 0x05://private
			}
			//*/
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
		
		private function readInstructionInfo(endPos:int):void
		{
			var instruction:Instruction = new Instruction();
			while(source.position < endPos){
				instruction.read(source);
				if(instruction.opcode == Constants.OP_pushstring){
					strIndexBlackList.addIndex(instruction.getImmAt(0));
				}
			}
			if(source.position != endPos){
				throw new Error("parse Instruction error");
				source.position = endPos;
			}
		}
	}
}