package snjdck.fileformat.abc
{
	import flash.utils.ByteArray;
	
	import snjdck.fileformat.abc.enum.Constants;
	import snjdck.fileformat.abc.io.Reader;

	public class Instruction
	{
		private var offset:int;
		private var size:int;
		
		public var opcode:int;
		private var imms:Vector.<int>;
		
		public function Instruction()
		{
			imms = new Vector.<int>();
		}
		
		public function getImmAt(index:int):int
		{
			return imms[index];
		}
		
		private function addImm(value:int):void
		{
			imms.push(value);
		}
		
		public function read(source:ByteArray):void
		{
			offset = source.position;
			opcode = source.readUnsignedByte();
			
			if(Constants.singleU32Imm.indexOf(opcode) >= 0) {
				addImm(Reader.ReadS32(source));
			} else if(Constants.doubleU32Imm.indexOf(opcode) >= 0) {
				addImm(Reader.ReadS32(source));
				addImm(Reader.ReadS32(source));
			} else if(Constants.singleS24Imm.indexOf(opcode) >= 0) {
				Reader.ReadS24(source);
			} else if(Constants.singleByteImm.indexOf(opcode) >= 0) {
				source.readUnsignedByte();
			} else if(opcode == Constants.OP_debug) {
				source.readUnsignedByte();
				Reader.ReadS32(source);
				source.readUnsignedByte();
				Reader.ReadS32(source);
			} else if(opcode == Constants.OP_lookupswitch) {
				Reader.ReadS24(source);
				var maxindex:int = Reader.ReadS32(source);
				while(maxindex-- >= 0){
					Reader.ReadS24(source);
				}
			}

			size = source.position - offset;
		}
		
		public function get hasName() : Boolean
		{
			return Constants.hasName.indexOf(opcode) != -1;
		}
		
		public function getOpcodeName():String {
			return Constants.opNames[opcode]
		}
		
		public function get isJump() : Boolean
		{
			switch(opcode) {
				case Constants.OP_ifnlt:
				case Constants.OP_ifnle:
				case Constants.OP_ifngt:
				case Constants.OP_ifnge:
				case Constants.OP_iftrue:
				case Constants.OP_iffalse:
				case Constants.OP_ifeq:
				case Constants.OP_ifne:
				case Constants.OP_iflt:
				case Constants.OP_ifle:
				case Constants.OP_ifgt:
				case Constants.OP_ifge:
				case Constants.OP_ifstricteq:
				case Constants.OP_ifstrictne:
				case Constants.OP_jump:
					return true;
			}
			return false;
		}
		
		public function get isBranch():Boolean {
			return isJump || (opcode == Constants.OP_lookupswitch);
		}
		
		public function get isTerminator():Boolean {
			switch(opcode) {
				case Constants.OP_throw:
				case Constants.OP_returnvalue:
				case Constants.OP_returnvoid:
					return true;
			}
			return false;
		}
	}
}