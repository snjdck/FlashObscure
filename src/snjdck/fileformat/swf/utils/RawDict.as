package snjdck.fileformat.swf.utils
{
	public class RawDict
	{
		public const keyList:Array = [];
		public const valList:Array = [];
		private var count:int;
		
		public function RawDict()
		{
		}
		
		public function getKeyAt(index:int):*
		{
			return keyList[index];
		}
		
		public function getValueAt(index:int):*
		{
			return valList[index];
		}
		
		public function getValue(key:Object):*
		{
			var index:int = keyList.indexOf(key);
			if(index >= 0){
				return getValueAt(index);
			}
		}
		
		public function addData(key:Object, value:Object):void
		{
			keyList[count] = key;
			valList[count] = value;
			++count;
		}
		
		public function removeAt(index:int):void
		{
			keyList.splice(index, 1);
			valList.splice(index, 1);
			--count;
		}
		
		public function mixStr():void
		{
			
		}
		
		public function mixPackage():void
		{
			for(var i:int=count-1; i>=0; --i){
				var list:Object = valList[i];
				if(list is String){
					continue;
				}
				var a:String = list[0];
				var b:String = list[1];
				var indexA:int = keyList.indexOf(a);
				var indexB:int = keyList.indexOf(b);
				var needUpdate:Boolean = false;
				if(indexA >= 0){
					a = valList[indexA];
					needUpdate = true;
				}
				if(indexB >= 0){
					b = valList[indexB];
					needUpdate = true;
				}
				if(needUpdate){
					valList[i] = a + ":" + b;
				}else{
					removeAt(i);
				}
			}
		}
		
		public function toString():String
		{
			var result:Array = [];
			for(var i:int=0; i<count; ++i){
				result.push(keyList[i] + "\t\t\t\t\t\t\t\t" + valList[i]);
			}
			return result.join("\n");
		}
	}
}