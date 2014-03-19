package snjdck.fileformat.swf.utils
{
	import array.has;
	
	import stdlib.random.random_boolean;
	import stdlib.random.random_digit;
	import stdlib.random.random_word;

	public function generateVariableName(nChar:int, excludeList:Array=null, addResultToExcludeList:Boolean=false):String
	{
		if(nChar < 1){
			throw new ArgumentError("nChar must > 0");
		}
		
		var str:String = random_boolean() ? "_" : random_boolean() ? "$" : random_word();
		
		while(str.length < nChar){
			str += random_boolean() ? "_" : random_boolean() ? "$" : random_boolean() ? random_word() : random_digit();
		}
		
		if(excludeList){
			if(array.has(excludeList, str)){
				return generateVariableName(nChar, excludeList);
			}else if(addResultToExcludeList){
				excludeList.push(str);
			}
		}
		
		return str;
	}
}