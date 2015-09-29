package snjdck.fileformat.abc.io
{
	import flash.utils.ByteArray;
	
	import lambda.callTimes;
	
	import snjdck.fileformat.abc.Instruction;
	import snjdck.fileformat.abc.StringSet;
	import snjdck.fileformat.abc.enum.Constants;
	
	/**
	 * black:metadata, function arg default value, pushstring
	 * white:function arg name
	 */
	final public class Reader
	{
		static public function ReadU29(data:ByteArray):int
		{
			var result:int = 0;
			var count:int = 0;
			for(;;){
				var byte:uint = data.readUnsignedByte();
				result |= byte & 0x7F;
				if((byte & 0x80) == 0){
					return result;
				}
				if(++count < 3){
					result <<= 7;
				}else{
					result <<= 8;
					break;
				}
			}
			result |= data.readUnsignedByte();
			if(result & 10000000){
				result = -(~(result-1) & 0x1FFFFFFF);
			}
			return result;
		}
		
		static public function ReadS32(data:ByteArray):int
		{
			var result:int = 0;
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
			readS32();//name index
			const flags:uint = data.readUnsignedByte();
			if(flags & Constants.HAS_OPTIONAL){//参数默认值
				repeatCall(readDefaultParam2);
			}
			if(flags & Constants.HAS_ParamNames){//参数名称
				callTimes(param_count, readParamName);
			}
		}
		
		private function readDefaultParam2():void
		{
			readDefaultParam(readS32());
		}
		
		public function readDefaultParam(valueIndex:int):void
		{
			var valueType:int = data.readUnsignedByte();
			if(valueType == Constants.CONSTANT_Utf8){
				blackSet.addIndex(valueIndex);
			}
		}
		
		private function readParamName():void
		{
			whiteSet.addIndex(readS32());
		}
		
		public function readExceptionList():void
		{
			callTimes(readS32() * 5, readS32);
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
			assert(data.position == endPos);
		}
		
		static private const instruction:Instruction = new Instruction();
	}
}