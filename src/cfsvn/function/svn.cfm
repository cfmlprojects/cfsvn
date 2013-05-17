<cffunction name="svn">
	<cfscript>
		var jm = createObject("WEB-INF.railo.customtags.cfsvn.cfc.svn");
		var results = jm.runAction(argumentCollection = arguments);
		return results;
	</cfscript>
</cffunction>