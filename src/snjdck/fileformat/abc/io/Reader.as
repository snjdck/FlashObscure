package snjdck.fileformat.abc.io
{
	import flash.utils.ByteArray;
	
	import lambda.callTimes;
	
	import snjdck.fileformat.abc.Instruction;
	import snjdck.fileformat.abc.StringSet;
	import snjdck.fileformat.abc.enum.Constants;

	final public class Reader
	{
		static public function ReadS32(data:ByteArray):int
		{
			var result:uint = 0;
			var count:int = 0;
			do{
				var byte:uint = data.readUnsignedByte();
				result |= (byte & 0x7f) << (count * 7);
				++count;
			}while((byte & 0x80) != 0 && count < 5);
			return result;
		}
		
		static public function ReadS24(data:ByteArray):int
		{
			var result:int = data.readUnsignedByte();
			result |= data.readUnsignedByte() << 8;
			result |= data.readByte() << 16;
			return result;
		}
		
		private var data:ByteArray;
		private var blackSet:StringSet;
		private var whiteSet:StringSet;
		
		public function Reader(data:ByteArray, blackSet:StringSet, whiteSet:StringSet)
		{
			this.data = data;
			this.blackSet = blackSet;
			this.whiteSet = whiteSet;
		}
		
		public function readS32():int
		{
			return ReadS32(data);
		}
		
		public function readS24():int
		{
			return ReadS24(data);
		}
		
		public function readDouble():Number
		{
			return data.readDouble();
		}
		/*
		public function readTwoS32():void
		{
			readS32();
			readS32();
		}
		*/
		public function readExceptionInfo():void{
			callTimes(5, readS32);
		}
		
		public function readMetadataInfo():void
		{
			blackSet.addIndex(readS32());//tagName
			repeatCall(readMetadataKeyValue);
		}
		
		private function readMetadataKeyValue():void
		{
			blackSet.addIndex(readS32());
			blackSet.addIndex(readS32());
		}
		
		public function readMethodInfo():void
		{
			const param_count:int = readS32();
			readS32();//return type
			callTimes(param_count, readS32);//paramType
			var nameIndex:int = readS32();
			if(nameIndex > 0){
				whiteSet.addIndex(nameIndex);
			}
			const flags:uint = data.readUnsignedByte();
			if(flags & Constants.HAS_OPTIONAL){//参数默认值
				repeatCall(readDefaultParam);
			}
			if(flags & Constants.HAS_ParamNames){//参数名称
				callTimes(param_count, readParamName);
			}
		}
		
		private function readDefaultParam():void
		{
			var index:int = readS32();//值在常量池中的索引
			var valueType:int = data.readUnsignedByte();
			switch(valueType){
				case Constants.CONSTANT_Utf8:
					blackSet.addIndex(index);
					break;
			}
		}
		
		private function readParamName():void
		{
			whiteSet.addIndex(readS32());
		}
		
		public function readS32List():void
		{
			repeatCall(readS32);
		}
		
		private function repeatCall(handler:Function):void
		{
			var count:uint = readS32();
			while(count-- > 0){
				handler();
			}
		}
		
		public function readInstructionList():void
		{
			var endPos:int = readS32() + data.position;
			while(data.position < endPos){
				instruction.read(data);
				if(instruction.opcode == Constants.OP_pushstring){
					blackSet.addIndex(instruction.getImmAt(0));
				}
			}
			assert(data.position == endPos, "parse op error!");
		}
		
		static private const instruction:Instruction = new Instruction();
	}
}