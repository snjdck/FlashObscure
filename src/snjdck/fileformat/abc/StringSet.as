package snjdck.fileformat.abc
{
	import array.pushIfNotHas;

	final public class StringSet
	{
		private var ref:Array;
		public var indexList:Array;
		
		public function StringSet(ref:Array)
		{
			this.indexList = [];
			this.ref = ref;
		}
		
		public function addStr(str:String):void
		{
			var strIndex:int = ref.indexOf(str);
			if(strIndex != -1){
				addIndex(strIndex);
			}
		}
		
		public function addIndex(index:int):Boolean
		{
			return pushIfNotHas(indexList, index);
		}
		
		public function toString():String
		{
			var result:Array = [];
			for each(var index:int in indexList){
				result.push(ref[index]);
			}
			return result.join("\n");
		}
	}
}