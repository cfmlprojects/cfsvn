<cfcomponent displayname="TestSvn"  extends="mxunit.framework.TestCase">  

	<cfimport taglib="/cfsvn/tag/cfsvn" prefix="gm" />

  <cffunction name="setUp" returntype="void" access="public">
		<cfset datapath = getAbsolutePath("#getDirectoryFromPath(getMetadata(this).path)#","../../data") />
		<cfset svndir = getAbsolutePath("#getDirectoryFromPath(getMetadata(this).path)#","../../work/svndir") />
		<cfset workingcopydir = getAbsolutePath("#getDirectoryFromPath(getMetadata(this).path)#","../../work/wc") />
		<cfset directoryExists(svndir) ? directoryDelete(svndir,true) : ""  />
		<cfset !directoryExists(workingcopydir) ? directoryCreate(workingcopydir,true) : ""  />
 		<cfset fileWrite(workingcopydir & "/test.txt","testing!") />
 		<cfset fileWrite(workingcopydir & "/test1.txt","testing!") />
 		<cfset fileWrite(workingcopydir & "/test2.txt","testing!") />
 		<cfset fileWrite(workingcopydir & "/test3.txt","testing!") />
 		<cfset variables.Svn = createObject("component","cfsvn.tag.cfsvn.cfc.svn") />
		<cfset variables.Svn.init(false) />
		<cfset variables.svn.doAction(action="createRepository",svnUrl="file:///#svndir#",overwrite="true") />
  </cffunction>

  <cffunction name="tearDown" returntype="void" access="public">
		<cfset directoryExists(svndir) ? directoryDelete(svndir,true) : ""  />
		<cfset directoryExists(workingcopydir) ? directoryDelete(workingcopydir,true) : ""  />
  </cffunction>

	<cffunction name="dumpvar" access="private">
		<cfargument name="var">
		<cfdump var="#var#">
		<cfabort/>
	</cffunction>

	<cffunction name="getAbsolutePath" access="public" returntype="string">
		<cfargument name="path">
		<cfargument name="relpath">
		<cfset var jfile = createObject("java","java.io.File") />
		<cfset var parentFolder = jfile.init(jfile.init(path).getParent()) />
		<cfset var abspath = jfile.init(parentFolder, relpath).getCanonicalPath() />
		<cfreturn abspath />
	</cffunction>

	<cffunction name="testListFiles">
		<cfscript>
			var commit1 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test1.txt", message="commited man",data="blah blah blah");
			var commit2 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test2.txt", message="commited man",data="blah blah blah");
			var commit3 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test3.txt", message="commited man",data="blah blah blah");
			var list = variables.svn.doAction(action="list",svnUrl="file:///#svndir#");
			request.debug(list);
			assertEquals(3,list.recordcount)
		</cfscript>
	</cffunction>

	<cffunction name="testGetFile">
		<cfscript>
			var commit = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test.txt", message="commited man",data="blah blah blah");
			var file = variables.svn.doAction(action="getFile",svnUrl="file:///#svndir#",resourcePath="test.txt");
			assertEquals(1,file.recordcount);
			assertEquals("blah blah blah",toString(file.content));
		</cfscript>
	</cffunction>

	<cffunction name="createRepository">
		<cfscript>
			var list = variables.svn.doAction(action="createRepository",svnUrl="file:///#svndir#",overwrite="true");
			debug(list);
		</cfscript>
	</cffunction>

	<cffunction name="testGetHistory">
		<cfscript>
			var commit1 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test.txt", message="commited man 1",data="blah");
			var commit2 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test.txt", message="commited man 2",data="blah blah");
			var commit3 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="test.txt", message="commited man 3",data="blah blah blah");
			var history = variables.svn.doAction(action="getHistory",svnUrl="file:///#svndir#",resourcePath="test.txt",revision="1");
			assertEquals(3,history.recordcount);
			//var list = variables.svn.doAction(action="getHistory",svnUrl="http://svn.riaforge.org/environmentConfig/wwwroot/Application.cfc");
		</cfscript>
	</cffunction>

	<cffunction name="testCommit">
		<cfscript>
			var list = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			list = variables.svn.doAction(action="list",svnUrl="file:///#svndir#");
			assertEquals(list.recordcount,1);
			debug(list);
		</cfscript>
	</cffunction>


	<cffunction name="testCommitWC">
		<cfscript>
			var com1 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var com2 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var results = variables.svn.doAction(action="checkout",svnUrl="file:///#svndir#", targetDir="#workingcopydir#", revision="-1");
		</cfscript>
		<cffile action="append" file="#workingcopydir#test.txt" output="new stuff" />
		<cfscript>
			com3 = variables.svn.doAction(action="commit",targetDir="#workingcopydir#");
			request.debug(com3);
			assertTrue(find("committed revision : r3",com3));
		</cfscript>
	</cffunction>

	<cffunction name="testCreateDirectory">
		<cfscript>
			var commit = variables.svn.doAction(action="createDirectory",svnUrl="file:///#svndir#",resourcePath="/testdir", message="commited man");
			list = variables.svn.doAction(action="list",svnUrl="file:///#svndir#");
			assertEquals(list.path,"/testdir");
		</cfscript>
	</cffunction>

	<cffunction name="testDelete">
		<cfscript>
			var commitdir = variables.svn.doAction(action="createDirectory",svnUrl="file:///#svndir#",resourcePath="/testdir", message="commited man");
			var commitfile = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/testdir/test.txt", message="commited man",data="blah blah blah");
			var deletefile = variables.svn.doAction(action="delete",svnUrl="file:///#svndir#",resourcePath="/testdir/test.txt", message="deleted man");
			var deletedir = variables.svn.doAction(action="delete",svnUrl="file:///#svndir#",resourcePath="/testdir", message="deleted man");
			list = variables.svn.doAction(action="list",svnUrl="file:///#svndir#");
			assertEquals(0,list.recordcount);
		</cfscript>
	</cffunction>

	<cffunction name="testExport">
		<cfscript>
			var list = variables.svn.doAction(action="export",svnUrl="file:///#svndir#", targetDir="/tmp/export/", revision="-1");
			list = variables.svn.doAction(action="list",svnUrl="file:///#svndir#");
			debug(list);
		</cfscript>
	</cffunction>

	<cffunction name="testCheckout">
		<cfscript>
			var com1 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var com2 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var results = variables.svn.doAction(action="checkout",svnUrl="file:///#svndir#", targetDir="#workingcopydir#", revision="-1");
			assertEquals("checked out revision : 2",results)
		</cfscript>
	</cffunction>

	<cffunction name="testUpdate">
		<cfscript>
			var checkout = testCheckout();
			var com3 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var com4 = variables.svn.doAction(action="commit",svnUrl="file:///#svndir#",resourcePath="/test.txt", message="commited man",data="blah blah blah");
			var results = variables.svn.doAction(action="update",targetDir="#workingcopydir#");
			assertEquals("updated to revision : 4",results)
		</cfscript>
	</cffunction>

</cfcomponent>