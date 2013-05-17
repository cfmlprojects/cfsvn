<cfsilent>
	<cfif NOT structKeyExists(thistag,"tag")>
		<cfset thistag.tag = createObject("component","cfc.svn") />
		<cfset thistag.tag.init(THISTAG.HasEndTag) />
	</cfif>
	<cfset tag = thistag.tag />
	<cfset attrs = tag.metadata.attributes />
	<cfset curScope = (structKeyExists(attributes,"argumentcollection")) ? "attributes.argumentcollection" : "attributes">
	<cfloop list="#structKeyList(attrs)#" index="attr">
		<cfif structKeyExists(attrs[attr],"default")>
			<cfparam name="#curScope#.#attr#" default="#attrs[attr].default#" />
		<cfelse>
			<cfparam name="#curScope#.#attr#" default="" />
		</cfif>
	</cfloop>
	<cfset request.debug(THISTAG.ExecutionMode)>
	<cfif (THISTAG.ExecutionMode EQ "start")>
		<cfset tag.onStartTag(attributes,caller) />
	</cfif>
</cfsilent>
<cfif (THISTAG.ExecutionMode EQ "end")>
	<cfset tag.onEndTag(attributes,caller,THISTAG.GeneratedContent) />
	<cfset THISTAG.GeneratedContent ="" />
</cfif>