<cfcomponent name="svn">

	<!--- Meta data --->
	<cfset this.metadata.attributetype="fixed">
    <cfset this.metadata.attributes={
		action:			{required:true,type:"string"},
		svnurl:			{required:false,type:"string"},
		resourcePath:			{required:false,type:"string",default:""},
		username:			{required:false,type:"string",default:""},
		password:			{required:false,type:"string",default:""},
		resultsVar:			{required:false,type:"string",default:"results"}
		}/>
         
	<cfset cl = new LibraryLoader(getDirectoryFromPath(getMetaData(this).path) & "lib/").init() />
	
    <cffunction name="init" output="no" returntype="void" hint="invoked after tag is constructed">
    	<cfargument name="hasEndTag" type="boolean" required="yes">
      	<cfargument name="parent" type="component" required="no" hint="the parent cfc custom tag, if there is one">
				<cfset var libs = "" />
				<cfset variables.hasEndTag = arguments.hasEndTag />
				<cfscript>
					var factories = structNew();
					this.svnurl = cl.create("org.tmatesoft.svn.core.SVNURL");
					this.wcutil = cl.create("org.tmatesoft.svn.core.wc.SVNWCUtil");
		 			factories["http"] = structNew();
		 			factories["http"]["drf"] = cl.create("org.tmatesoft.svn.core.internal.io.dav.DAVRepositoryFactory").setup();
		 			factories["http"]["factory"] = cl.create("org.tmatesoft.svn.core.internal.io.dav.DAVRepositoryFactory");
		 			factories["file"] = structNew();
		 			factories["file"]["drf"] = cl.create("org.tmatesoft.svn.core.internal.io.fs.FSRepositoryFactory").setup();
		 			factories["file"]["factory"] = cl.create("org.tmatesoft.svn.core.internal.io.fs.FSRepositoryFactory");
		/*
		 			factories["svn"] = structNew();
		 			factories["svn"]["drf"] = cl.create("org.tmatesoft.svn.core.internal.io.svn.SVNRepositoryFactory").setup();
		 			factories["svn"]["factory"] = cl.create("org.tmatesoft.svn.core.internal.io.svn.SVNRepositoryFactory");
		 */
		 			variables.factories = factories;
				</cfscript>
  	</cffunction> 
    
    <cffunction name="onStartTag" output="yes" returntype="boolean">
   		<cfargument name="attributes" type="struct">
   		<cfargument name="caller" type="struct">
			<cfscript>
				var repositoryUrl = attributes.svnUrl;
				var username = attributes.username;
				var password = attributes.password;
				var repo = "";
				var results = "";
				
				if(repositoryUrl neq '') {
					repo = getRepository(repositoryUrl,username,password);
				}
				
				switch(attributes.action) {
					case "list": {
						results = list(repo,attributes.resourcePath);
	          break;
					}
					case "getFile": {
						results = getFile(repo,attributes.resourcePath);
	          break;
					}
					case "createRepository": {
						results = createRepository(repositoryUrl,attributes.overwrite);
	          break;
					}
					case "getHistory": {
						results = history(repo,attributes.resourcePath,attributes.revision);
	          break;
					}
					case "commit": {
						if(structKeyExists(attributes,"targetDir")) {
							results = commitWorkingCopy(attributes.targetDir,attributes.message);
						} else {
							results = commitResource(repo,attributes.resourcePath,attributes.message,attributes.data);
						}
	          break;
					}
					case "delete": {
						results = deleteResource(repo,attributes.resourcePath,attributes.message);
	          break;
					}
					case "export": {
						results = export(attributes.svnUrl,attributes.targetDir,attributes.revision,attributes.username,attributes.password);
	          break;
					}
					case "checkout": {
						results = checkout(attributes.svnUrl,attributes.targetDir,attributes.revision,attributes.username,attributes.password);
	          break;
					}
					case "createDirectory": {
						results = createDirectory(repo,attributes.resourcePath,attributes.message);
	          break;
					}
					case "update": {
						results = update(attributes.targetDir);
	          break;
					}
					
				}
				caller[attributes.resultsVar] = results;
			</cfscript>
			<cfif not variables.hasEndTag>
				<cfset onEndTag(attributes,caller,"") />
			</cfif>
	    <cfreturn variables.hasEndTag>   
		</cffunction>

    <cffunction name="onEndTag" output="yes" returntype="boolean">
   		<cfargument name="attributes" type="struct">
   		<cfargument name="caller" type="struct">				
  		<cfargument name="generatedContent" type="string">
		<cfreturn false/>	
	</cffunction>

    <cffunction name="doAction" output="false" returntype="any">
			<cfargument name="action" required="true" />
			<cfargument name="svnurl" default="" />
			<cfargument name="resourcePath" default="" />
			<cfargument name="username" default="" />
			<cfargument name="password" default="" />
			<cfargument name="message" default="" />
			<cfargument name="data" default="" />
			<cfargument name="overwrite" default="false" />
			<cfargument name="resultsVar" default="svn" />
			<cfscript>
				var results = structNew();
				var attribs = structNew();
/*
 				attribs.action=arguments.action;
				attribs.svnurl=arguments.svnurl;
				attribs.username=arguments.username;
				attribs.password=arguments.password;
				attribs.overwrite=true;
				attribs.resultsvar="svn";
 */
 				this.init(false);
				onStartTag(attributes=arguments,caller=results);
				return results[resultsVar];
			</cfscript>
		</cffunction>

<!--- BEGIN FUNKY STUFF --->

	<cffunction name="getLatestRevision" access="private" returntype="any" output="false">
		<cfreturn getRepository().getLatestRevision() />
	</cffunction>

	<cffunction name="getAuthManager" access="private" returntype="any" output="false">
		<cfargument name="user" required="true" />
		<cfargument name="pass" required="true" />
		<cfscript>
			var username = arguments.user;
			var password = arguments.pass;
			var authManager = this.wcutil.createDefaultAuthenticationManager(username,password);
			return authManager;
		</cfscript>
	</cffunction>
	
	<cffunction name="getRepository" access="public" returntype="any" output="false">
		<cfargument name="repoUrl" required="true">
		<cfargument name="user" default="">
		<cfargument name="pass" default="">
		<cfscript>
			var repositoryUrl = arguments.repoUrl;
			var username = arguments.user;
			var password = arguments.pass;
			var protocol = lcase(left(repositoryUrl,4));			
			var factory = variables.factories[protocol]["factory"];
			var repository = factory.create(this.svnurl.parseURIEncoded(repositoryUrl));
			var authManager = getAuthManager(username,password);
			if (username NEQ ""){
				repository.setAuthenticationManager(authManager);
			}
			if (protocol eq "file" AND NOT fileExists(replaceNoCase(repositoryUrl,"file:///","")&"/format")) {
				createRepository(replaceNoCase(repositoryUrl,"file:///",""));
			}
			//	dumpvar(this,true);
			return repository;
		</cfscript>
	</cffunction>

	<cffunction name="resourceExists" output="false" description="Fetch a log of a given revision" returntype="boolean">
		<cfargument name="repos" required="true" />
		<cfargument name="resourceURL" type="string" required="true" />
		<cfargument name="revision" default="-1" />
		<cfscript>
				var repository = arguments.repos;
        var nodeKind = repository.checkPath(JavaCast("string",arguments.resourceURL),JavaCast("int",arguments.revision));
		  	if(nodeKind.compareTo(nodeKind.NONE) EQ 0) {
		  		return false;
		  	} else {
		  		return true;
		  	}
		</cfscript>
	</cffunction>

	<cffunction name="createRepository" output="false" description="create an SVN repository" returntype="any">
		<cfargument name="repositoryFilePath" required="true">		
		<cfargument name="overwrite" default="false">
		<cfargument name="propRevisions" default="false">
<!---
 		<cfset var repoFactory = cl.create("org.tmatesoft.svn.core.internal.io.SVNRepositoryFactory")>
 --->
		<cfset var repoFile = cl.create("java.io.File").init(arguments.repositoryFilePath)>
	  <cfset var factory = variables.factories["file"]["factory"]>
	  <cfset var repo = factory.createLocalRepository( repoFile, javacast("null",""), true , arguments.overwrite )>
	  <cfreturn repo.toString() />
	</cffunction>

	<cffunction name="List" output="false" description="Retrieve a list of children for a resource" returntype="query">
		<cfargument name="repos" required="true">
		<cfargument name="Resource" type="string" required="true">
		<cfset var Q=QueryNew("Name,Author,Message,Date,Kind,Path,RelativePath,ParentPath,Revision,Size,URL,Content")>
		<cfset var ent=cl.create("java.util.LinkedHashSet").init(16)>
		<cfset var i="">
		<cfset var f="">
		<cfset var u="">
		<cfset var NodeKind="">
		<cfset var repositoryUrl = arguments.repos.location.toDecodedString() />
		<cfset var repository = arguments.repos />
		<!--- <cfset arguments.resource = this.repositoryBasepath & arguments.resource /> --->
		<cftry>
			<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",-1))>
			<cfcatch>
				<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",-1))>
			</cfcatch>
		</cftry>
<!--- 		<cfif (nodeKind.compareTo(nodeKind.DIR) EQ 0)>
 --->			<cfset repository.getDir(JavaCast("string",Arguments.Resource),JavaCast("int",-1),false,ent)>
			<cfset i=ent.iterator()>
			<cfloop condition="i.hasNext()">
				<cfset f=i.next()>
				<cfset QueryAddRow(Q)>
				<cfset Q.Name[Q.RecordCount]=f.getName()>
				<cfset Q.Author[Q.RecordCount]=f.getAuthor()>
				<cfset Q.Message[Q.RecordCount]=f.getCommitMessage()>
				<cfset Q.Date[Q.RecordCount]=f.getDate()>
				<cfset Q.Kind[Q.RecordCount]=f.getKind().toString()>
				<cfset Q.Path[Q.RecordCount]=f.getPath()>
				<cfset Q.RelativePath[Q.RecordCount]=f.getRelativePath()>
				<cfset Q.Revision[Q.RecordCount]=f.getRevision()>
				<cfset Q.Size[Q.RecordCount]=f.getSize()>
				<cfset u=f.getURL().toString()>
				<cfset Q.URL[Q.RecordCount]=u>
				<cfif Left(u,Len(repositoryUrl)) EQ repositoryUrl><cfset u=Mid(u,Len(repositoryUrl)+1,Len(u))></cfif>
				<!--- TODO: something different? remove repository path for now --->
				<cfset repositoryUrl = replaceNoCase(repositoryUrl,"file:////","file:///","all")>
				<cfset u = replaceNoCase(u,repositoryUrl,"","all")>
				<cfif listLen(u,"/") gt 1>
					<cfset Q.ParentPath[Q.RecordCount]=listDeleteAt(u,listLen(u,"/"),"/") />
				<cfelse>
					<cfset Q.ParentPath[Q.RecordCount]="/" />
				</cfif>
				<cfset Q.Path[Q.RecordCount]=u />
			</cfloop>
			<cfquery dbtype="query" name="Q">
			SELECT *
			FROM Q
			ORDER BY Kind, URL, Revision DESC
			</cfquery>
		<!--- </cfif> --->
		<cfreturn Q>
	</cffunction>
	
	<cffunction name="getFile" output="false" description="Retrieve the specific version of a file" returntype="query">
		<cfargument name="repos" required="true">
		<cfargument name="Resource" type="string" required="true">
		<cfargument name="Version" type="numeric" default="-1">
		<cfset var Q=QueryNew("Name,Author,Message,Date,Kind,Path,Revision,Size,URL,Content,MimeType")>
		<cfset var props=cl.create("org.tmatesoft.svn.core.SVNProperties")>
		<cfset var out=cl.create("java.io.ByteArrayOutputStream").init()>
		<cfset var MimeType="">
		<cfset var NodeKind="">
		<cfset var PageContext=getPageContext()>
		<cfset var repository = arguments.repos />
		<!--- <cfset arguments.resource = this.repositoryBasepath & arguments.resource /> --->
		<cftry>
			<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",Arguments.Version))>
			<cfcatch>
				<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",Arguments.Version))>
			</cfcatch>
		</cftry>
		<cfif NodeKind.compareTo(NodeKind.FILE) EQ 0>
			<cfset repository.getFile(JavaCast("string",Arguments.Resource),JavaCast("int",Arguments.Version),props,out)>
			<cfset props = props.asMap()>
			<cfset QueryAddRow(Q)>
			<cfset Q.Name[Q.RecordCount]=ListLast(Arguments.Resource,"/")>
			<cfif StructKeyExists(props,"svn:entry:last-author")>
				<cfset Q.Author[Q.RecordCount]=props["svn:entry:last-author"].getString()>
			</cfif>
			<cfset Q.Date[Q.RecordCount]=CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'").parse(props["svn:entry:committed-date"], CreateObject("java", "java.text.ParsePosition").init(0))>
			<cfset Q.Kind[Q.RecordCount]="file">
			<cfset Q.Path[Q.RecordCount]=Mid(Arguments.Resource,1,Len(Arguments.Resource))>
			<cfset Q.Revision[Q.RecordCount]=props["svn:entry:committed-rev"].getString()>
			<cfset Q.Size[Q.RecordCount]=out.size()>
			<cfset Q.URL[Q.RecordCount]=Mid(Arguments.Resource,1,Len(Arguments.Resource))>
			<cfset Q.Content[Q.RecordCount]=out.toByteArray()>
			<cfset MimeType=PageContext.getServletContext().getMimeType(Q.Name[Q.RecordCount])>
			<cfif NOT IsDefined("MimeType")>
				<cfset FileExt=LCase(ListLast(Q.Name[Q.RecordCount],"."))>
				<cfswitch expression="#FileExt#">
					<cfcase value="cfc,cfm,cfml,js,pl,plx,php,php4,php5,asp,aspx,sql"><cfset MimeType="text/plain"></cfcase>
					<cfcase value="jpg,jpeg,png,gif,ico"><cfset MimeType="image/"&FileExt></cfcase>
					<cfcase value="xml,html,htm"><cfset MimeType="text/"&FileExt></cfcase>
					<cfdefaultcase><cfset MimeType="application/octet-stream"></cfdefaultcase>
				</cfswitch>
			</cfif>
			<cfset Q.MimeType[Q.RecordCount]=MimeType>
		</cfif>
		<cfreturn Q>


	</cffunction>
	
	<cffunction name="History" output="false" description="Fetch a history of a given resource" returntype="query">
		<cfargument name="repos" required="true">
		<cfargument name="Resource" type="string" required="true">
		<cfargument name="revision" type="numeric" default="-1">
		<cfset var Q=QueryNew("Name,Author,Message,Date,Kind,Path,Revision,Size,URL,Content")>
		<cfset var ent=cl.create("java.util.LinkedHashSet").init(16)>
		<cfset var i="">
		<cfset var f="">
		<cfset var u="">
		<cfset var lastRev=-1 />
		<cfset var NodeKind="">
		<cfset var repository = arguments.repos />
		<!--- <cfset var repositoryUrl = variables._config.getConfigSetting("RepositoryURL")> --->
		<cfset arguments.resource = arguments.resource />
		<cftry>
			<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",lastRev))>
			<cfcatch>
				<cfset NodeKind=repository.checkPath(JavaCast("string",Arguments.Resource),JavaCast("int",lastRev))>
			</cfcatch>
		</cftry>
		<cfif NodeKind.compareTo(NodeKind.FILE) EQ 0>
			<cfset u=ArrayNew(1)>
			<cfset ArrayAppend(u,arguments.resource)>
			<cfset lastRev=repository.getLatestRevision()>
			<cfset repository.log(u,ent,JavaCast("int",arguments.revision),JavaCast("int",lastRev),false,true)>
			<cfset i=ent.iterator()>
			<cfloop condition="i.hasNext()">
				<cfset f=i.next()>
				<cfset QueryAddRow(Q)>
				<cfset Q.Message[Q.RecordCount]=f.getMessage()>
				<cfset Q.Date[Q.RecordCount]=f.getDate()>
				<cfset Q.Author[Q.RecordCount]=f.getAuthor()>
				<cfset Q.Revision[Q.RecordCount]=f.getRevision()>
				<cfset Q.Path[Q.RecordCount]=Mid(Arguments.Resource,1,Len(Arguments.Resource))>
				<cfset Q.Name[Q.RecordCount]=ListLast(Arguments.Resource,"/")>
				<cfset Q.Kind[Q.RecordCount]="file">
			</cfloop>
			<cfquery dbtype="query" name="Q">
			SELECT *
			FROM Q
			ORDER BY Revision DESC
			</cfquery>
		<cfelse>
			<cfset repository.getDir(JavaCast("string",Arguments.Resource),JavaCast("int",-1),false,ent)>
			<cfset i=ent.iterator()>
			<cfloop condition="i.hasNext()">
				<cfset f=i.next()>
				<cfset QueryAddRow(Q)>
				<cfset Q.Name[Q.RecordCount]=f.getName()>
				<cfset Q.Author[Q.RecordCount]=f.getAuthor()>
				<cfset Q.Message[Q.RecordCount]=f.getCommitMessage()>
				<cfset Q.Date[Q.RecordCount]=f.getDate()>
				<cfset Q.Kind[Q.RecordCount]=f.getKind().toString()>
				<cfset Q.Path[Q.RecordCount]=f.getRelativePath()>
				<cfset Q.Revision[Q.RecordCount]=f.getRevision()>
				<cfset Q.Size[Q.RecordCount]=f.getSize()>
				<cfset u=f.getURL().toString()>
				<!--- <cfif Left(u,Len(repositoryUrl)) EQ repositoryUrl><cfset u=Mid(u,Len(repositoryUrl)+1,Len(u))></cfif> --->
				<cfset Q.URL[Q.RecordCount]=u>
			</cfloop>
			<cfquery dbtype="query" name="Q">
			SELECT *
			FROM Q
			ORDER BY Kind, URL, Revision DESC
			</cfquery>
		</cfif>
		<cfreturn Q>
	</cffunction>

	<cffunction name="changeSet" output="false" description="Fetch a log of a given revision" returntype="query">
		<cfargument name="repos" required="true">
		<cfargument name="firstRevision" type="string" required="true">
		<cfargument name="lastRevision" type="string" required="true">
		<cfset var repository = arguments.repos />
		<cftry>
			<cfscript>
				svnWrap = createObject("java",'svnWrap');
				logEntries = svnWrap.getLogEntries(repository,arguments.firstRevision,arguments.lastRevision);
			</cfscript>
			<cfif not isDefined('logEntries')>
				<cfset logentries ="Java Err!">
			</cfif>
		<cfcatch><cfdump var="#cfcatch#"><cfabort></cfcatch>
		</cftry>
		<cfdump var="#xmlParse(logEntries[1])#">
		<cfabort>
	</cffunction>

	<cffunction name="addResource" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="repos" required="true">
		<cfargument name="resourceUrl" type="string" required="true">
		<cfargument name="message" type="string" required="true">
		<cfargument name="data" required="true">
			<cfscript>
				var repository = arguments.repos;
				var checksum = "";
				var commitMessage = arguments.message;
				var filedata = toBinary(toBase64(arguments.data));
				var filepath = this.repositoryBasepath & arguments.resourceUrl;
				var dirpath = listDeleteAt(filepath,listLen(filepath,"/"),"/");
				var editor = repository.getCommitEditor(commitMessage,javacast("null",""));
				var deltaGenerator = cl.create("org.tmatesoft.svn.core.io.diff.SVNDeltaGenerator");
				arguments.resourceUrl = this.repositoryBasepath & arguments.resourceUrl;
        editor.openRoot(javacast("int",-1));
        editor.openDir(javacast("string",dirPath), javacast("int",-1));
        /*
         * Adds a new file to the just added  directory. The  file  path is also 
         * defined as relative to the root directory.
         *
         * copyFromPath (the 2nd parameter) is set to null and  copyFromRevision
         * (the 3rd parameter) is set to -1 since  the file is  not  added  with 
         * history.
         */
        editor.addFile(filePath, javacast("null",""), javacast("int",-1));
        /*
         * The next steps are directed to applying delta to the  file  (that  is 
         * the full contents of the file in this case).
         */
        editor.applyTextDelta(filePath, javacast("null",""));
        /*
         * Use delta generator utility class to generate and send delta
         * 
         * Note that you may use only 'target' data to generate delta when there is no 
         * access to the 'base' (previous) version of the file. However, using 'base' 
         * data will result in smaller network overhead.
         * 
         * SVNDeltaGenerator will call editor.textDeltaChunk(...) method for each generated 
         * "diff window" and then editor.textDeltaEnd(...) in the end of delta transmission.  
         * Number of diff windows depends on the file size. 
         *  
         */
				inStream = cl.create("java.io.ByteArrayInputStream").init(fileData);
        checksum = deltaGenerator.sendDelta(filePath, inStream, editor, true); 
        /*
         * Closes the new added file.
         */
        editor.closeFile(filePath, checksum);
        /*
         * Closes the root directory.
         */
        editor.closeDir();
        editor.closeDir();
        /*
         * This is the final point in all editor handling. Only now all that new
         * information previously described with the editor's methods is sent to
         * the server for committing. As a result the server sends the new
         * commit information.
         */
        retEdit = editor.closeEdit();
 			</cfscript>
			<cfreturn retEdit />
<!---
 			<cfdump var="#retEdit#">
		<cfabort>
 --->
	</cffunction>

	<cffunction name="commitResource" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="repos" required="true">
		<cfargument name="resourceUrl" type="string" required="true">
		<cfargument name="message" type="string" required="true">
		<cfargument name="data" required="true">
			<cfscript>
				var isRecursive = true; // recursivly add any directories that do not exist
				var repository = arguments.repos;
				var checksum = "";
				var commitMessage = arguments.message;
				var filedata = toBinary(toBase64(arguments.data));
				var filepath = arguments.resourceUrl;
 				var dirpath = listDeleteAt(filepath,listLen(filepath,"/"),"/");
				var editor = "";
				var retEdit = "";
				var deltaGenerator = cl.create("org.tmatesoft.svn.core.io.diff.SVNDeltaGenerator");
				var props=cl.create("org.tmatesoft.svn.core.SVNProperties");
				var out=cl.create("java.io.ByteArrayOutputStream").init();
				var curDir = "/";
				var addDirs = "";
				var x = "";

        for(x=1;x lte listLen(dirPath,"/");x=x+1) {
        	curDir = curDir & listGetAt(dirPath,x,"/") & "/";
          if (NOT resourceExists(repository,curDir)) {
	        	addDirs = listAppend(addDirs,left(curDir,len(curDir)-1));
          }
        }
 //       dumpvar(addDirs);

		  	if(NOT resourceExists(repository,resourceUrl)) {
		  		request.debug(javacast("null",0));
					editor = repository.getCommitEditor(commitMessage,javacast("null",""));
	        editor.openRoot(javacast("int",-1));
	        if(isRecursive) {
		        for(x=1;x lte listLen(addDirs);x=x+1) {
			        	editor.addDir(listGetAt(addDirs,x), javacast("null","null"), javacast("int",-1));
				        editor.closeDir();
		        }
	        }

	        editor.openDir(javacast("string",dirPath), javacast("int",-1));
	        /*
	         * copyFromPath (the 2nd parameter) is set to null and  copyFromRevision
	         * (the 3rd parameter) is set to -1 since  the file is  not  added  with 
	         * history.
	         */
	        editor.addFile(filePath, javacast("null",""), javacast("int",-1));
	        /*
	         * The next steps are directed to applying delta to the  file  (that  is 
	         * the full contents of the file in this case).
	         */
	        editor.applyTextDelta(filePath, javacast("null",""));
	        /*
	         * Use delta generator utility class to generate and send delta
	         * 
	         * Note that you may use only 'target' data to generate delta when there is no 
	         * access to the 'base' (previous) version of the file. However, using 'base' 
	         * data will result in smaller network overhead.
	         * 
	         * SVNDeltaGenerator will call editor.textDeltaChunk(...) method for each generated 
	         * "diff window" and then editor.textDeltaEnd(...) in the end of delta transmission.  
	         * Number of diff windows depends on the file size. 
	         *  
	         */
					inStream = cl.create("java.io.ByteArrayInputStream").init(fileData);
	        checksum = deltaGenerator.sendDelta(filePath, inStream, editor, true);
	        /*
	         * Closes the new added file.
	         */
	        editor.closeFile(filePath, checksum);
		  	}
		  	// We will try to update, since something exists at the resourceURL
		  	else {
					repository.getFile(JavaCast("string",arguments.ResourceUrl),JavaCast("int",-1),props,out);
					editor = repository.getCommitEditor(commitMessage,javacast("null",""));
	        editor.openRoot(javacast("int",-1));
	        editor.openDir(javacast("string",dirPath), javacast("int",-1));
	        editor.openFile(javacast("string",filePath), javacast("int",-1));
	        editor.applyTextDelta(filePath, javacast("null",""));
					newFileIS = cl.create("java.io.ByteArrayInputStream").init(fileData);
					oldFileIS = cl.create("java.io.ByteArrayInputStream").init(out.toByteArray());
	        checksum = deltaGenerator.sendDelta(filePath, oldFileIS, javacast("int",0), newFileIS, editor, true);
	        editor.closeFile(filePath, checksum);
		  	}

        /*
         * Closes the root directory.
         */
        editor.closeDir();
        editor.closeDir();
        /*
         * This is the final point in all editor handling. Only now all that new
         * information previously described with the editor's methods is sent to
         * the server for committing. As a result the server sends the new
         * commit information.
         */
        retEdit = editor.closeEdit();
 			</cfscript>
			<cfreturn retEdit />
<!---
 			<cfdump var="#retEdit#">
		<cfabort>
 --->
	</cffunction>

	<cffunction name="deleteResource" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="repos" required="true">
		<cfargument name="resourceUrl" type="string" required="true">
		<cfargument name="message" type="string" required="true">
			<cfscript>
				var repository = arguments.repos;
				var checksum = "";
				var commitMessage = arguments.message;
				var filepath = arguments.resourceUrl;
 				var dirpath = listDeleteAt(filepath,listLen(filepath,"/"),"/");
        var nodeKind = repository.checkPath(JavaCast("string",arguments.resourceURL),JavaCast("int",-1));
				var editor = "";
				var retEdit = "";
				var notFound = false;
				var deltaGenerator = cl.create("org.tmatesoft.svn.core.io.diff.SVNDeltaGenerator");
				var props=cl.create("java.util.HashMap").init(16);
		  	if(NodeKind.compareTo(NodeKind.NONE) NEQ 0) {
					editor = repository.getCommitEditor(commitMessage,javacast("null",""));
	        editor.openRoot(javacast("int",-1));
	        editor.deleteEntry(filePath, javacast("int",-1));
	        editor.closeDir();
	        retEdit = editor.closeEdit();
		  	}
		  	// non-existant resource - nothing to delete
		  	else {
		  		notFound = true;
		  	}

        /*
         * Closes the root directory.
         */
 			</cfscript>
			<cfif notFound>
				<cfthrow type="svn.delete.notFound" message="resource not found: #arguments.resourceUrl#" detail="resource not found: #arguments.resourceUrl#" />
			</cfif>
			<cfreturn retEdit />
<!---
 			<cfdump var="#retEdit#">
		<cfabort>
 --->
	</cffunction>

	<cffunction name="createDirectory" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="repos" required="true">
		<cfargument name="directory" type="string" required="true">
		<cfargument name="commitmessage" type="string" required="true">
			<cfscript>
				var repository = arguments.repos;
				var dirpath = arguments.directory;
        var nodeKind = repository.checkPath(JavaCast("string",dirpath),JavaCast("int",-1));
        var editor = "";
				var retEdit = "";
//        dumpvar(directory&"  " & commitMessage);
		  	if(NodeKind.compareTo(NodeKind.NONE) EQ 0) {
					editor = repository.getCommitEditor(arguments.commitMessage,javacast("null",""));
					try {
		        editor.openRoot(javacast("int",-1));
		        /*
		         * Adds a new directory  
		         * 
		         * dirPath is relative to the root directory.
		         * 
		         * copyFromPath (the 2nd parameter) is set to null and  copyFromRevision
		         * (the 3rd) parameter is set to  -1  since  the  directory is not added 
		         * with history (is not copied, in other words).
		         */
		        editor.addDir(dirpath, javacast("null",""), javacast("int",-1));
		        editor.closeDir();
		        editor.closeDir();
		        retEdit = editor.closeEdit();
					} catch(any except) {
						dumpvar(except);
					}
		  	}
		  	else {
		  		return "directory already exists";
		  	}
 			</cfscript>
			<cfreturn retEdit />
<!---
 			<cfdump var="#retEdit#">
		<cfabort>
 --->
	</cffunction>

	<cffunction name="modifyResource" output="false" description="Fetch a log of a given revision" returntype="query">
		<cfargument name="repos" required="true">
		<cfargument name="resourceUrl" type="string" required="true">
		<cfargument name="message" type="string" required="true">
		<cfargument name="data" required="true">
			<cfscript>
				var repository = arguments.repos;
				var checksum = "";
				var commitMessage = arguments.message;
				var filedata = toBinary(toBase64(arguments.data));
				var filepath = this.repositoryBasepath & arguments.resourceUrl;
				var dirpath = listDeleteAt(filepath,listLen(filepath,"/"),"/");
				var editor = repository.getCommitEditor(commitMessage,javacast("null",""));
				var retEdit = "";
				var deltaGenerator = cl.create("org.tmatesoft.svn.core.io.diff.SVNDeltaGenerator");

				editor = repository.getCommitEditor(commitMessage,javacast("null",""));
				deltaGenerator = cl.create("org.tmatesoft.svn.core.io.diff.SVNDeltaGenerator"); 

        editor.openRoot(javacast("int",-1));
        editor.openDir(javacast("string",dirPath), javacast("int",-1));
        editor.openFile(javacast("string",filePath), javacast("int",-1));
        editor.applyTextDelta(filePath, javacast("null",""));
				newFileIS = cl.create("java.io.ByteArrayInputStream").init(fileData);
				currentVersion = FileVersion(resourceUrl,-1);
				oldFileIS = cl.create("java.io.ByteArrayInputStream").init(currentVersion.content);
        checksum = deltaGenerator.sendDelta(filePath, oldFileIS, javacast("int",0), newFileIS, editor, true);
        editor.closeFile(filePath, checksum);
        editor.closeDir();
        editor.closeDir();
        // run the commit
        retEdit = editor.closeEdit();
 			</cfscript>
			<cfdump var="#retEdit#">
		<cfabort>

	</cffunction>


	<cffunction name="Export" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="resourceUrl" default="#variables._config.getConfigSetting("RepositoryURL")#">
		<cfargument name="targetDir" default="#variables._config.getConfigSetting("RepositoryURL")#">
		<cfargument name="exportRevision" default="head">
		<cfargument name="username" default="">
		<cfargument name="password" default="">
		<cfscript>
			/*	 doExport(SVNURL url,
                     File dstPath,
                     SVNRevision pegRevision,
                     SVNRevision revision,
                     String eolStyle,
                     boolean force,
                     boolean recursive)
              throws SVNException
       */
			var exportURL = arguments.resourceUrl;
			var targetDir = cl.create("java.io.File").init(arguments.targetDir);
			var pegRevision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision").parse(arguments.exportRevision);
			var revision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision").parse(arguments.exportRevision);
			var exporter = cl.create("org.tmatesoft.svn.core.wc.SVNUpdateClient").init(getAuthManager(arguments.username,arguments.password),javacast("null",""));
			exporter.doExport(this.svnurl.parseURIEncoded(exportURL),targetDir,pegRevision,revision,javacast("string","native"),true,true);
			return "exported";
		</cfscript>
	</cffunction>


	<cffunction name="checkout" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="resourceUrl" default="#variables._config.getConfigSetting("RepositoryURL")#">
		<cfargument name="targetDir" default="#variables._config.getConfigSetting("RepositoryURL")#">
		<cfargument name="exportRevision" default="head">
		<cfargument name="username" default="">
		<cfargument name="password" default="">
		<cfscript>
			/*	 doExport(SVNURL url,
                     File dstPath,
                     SVNRevision pegRevision,
                     SVNRevision revision,
                     String eolStyle,
                     boolean force,
                     boolean recursive)
              throws SVNException
       */
			var exportURL = arguments.resourceUrl;
			var targetDir = cl.create("java.io.File").init(arguments.targetDir);
			var pegRevision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision").parse(arguments.exportRevision);
			var revision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision").parse(arguments.exportRevision);
			var svndepth = cl.create("org.tmatesoft.svn.core.SVNDepth");
			
			var exporter = cl.create("org.tmatesoft.svn.core.wc.SVNUpdateClient").init(getAuthManager(arguments.username,arguments.password),javacast("null",""));
			exporter.setIgnoreExternals(false);			
			return "checked out revision : " & exporter.doCheckout(this.svnurl.parseURIEncoded(exportURL),targetDir,pegRevision,revision,SVNDepth.fromRecurse(true),true);
		</cfscript>
	</cffunction>

	<cffunction name="update" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="targetDir" default="#variables._config.getConfigSetting("RepositoryURL")#">
		<cfargument name="username" default="">
		<cfargument name="password" default="">
		<cfscript>
			/*	 doExport(SVNURL url,
                     File dstPath,
                     SVNRevision pegRevision,
                     SVNRevision revision,
                     String eolStyle,
                     boolean force,
                     boolean recursive)
              throws SVNException
       */
			var targetDir = cl.create("java.io.File").init(arguments.targetDir);
			var svnrevision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision");
			var svndepth = cl.create("org.tmatesoft.svn.core.SVNDepth");
			
			var exporter = cl.create("org.tmatesoft.svn.core.wc.SVNUpdateClient").init(getAuthManager(arguments.username,arguments.password),javacast("null",""));
			exporter.setIgnoreExternals(false);			
			return "updated to revision : " & exporter.doUpdate(targetDir,svnrevision.HEAD,SVNDepth.INFINITY,false,false);
		</cfscript>
	</cffunction>

	<cffunction name="commitWorkingCopy" output="false" description="Fetch a log of a given revision" returntype="any">
		<cfargument name="targetDir" required="true" />
		<cfargument name="commitMessage" default="" />
		<cfargument name="recursive" default="true" />
		<cfargument name="force" default="false" />
		<cfargument name="keepLocks" default="false" />
		<cfargument name="username" default="" />
		<cfargument name="password" default="" />
		<cfscript>
			/*	 doExport(SVNURL url,
                     File dstPath,
                     SVNRevision pegRevision,
                     SVNRevision revision,
                     String eolStyle,
                     boolean force,
                     boolean recursive)
              throws SVNException
       */
			var targetDir = cl.create("java.io.File").init(arguments.targetDir);
			var svnrevision = cl.create("org.tmatesoft.svn.core.wc.SVNRevision");
			var svndepth = cl.create("org.tmatesoft.svn.core.SVNDepth");			
			var exporter = cl.create("org.tmatesoft.svn.core.wc.SVNCommitClient").init(getAuthManager(arguments.username,arguments.password),javacast("null",""));
			var paths = createJavaArray("java.io.File",1);
			setJavaArray(paths,0,targetDir);
			 
			return "committed revision : " & exporter.doCommit(paths, arguments.keepLocks, arguments.commitMessage, arguments.force, arguments.recursive);
		</cfscript>
	</cffunction>

 	<cffunction name="createJavaArray" access="private" hint="I create and return a Java Array of the specified type." output="false" returntype="any">
    <cfargument name="typeName" hint="I am the type of array to create." required="yes" type="string" />
    <cfargument name="size" hint="I am the size of the array to create." required="yes" type="numeric" />
    <cfset NewArray = createObject("java", "java.lang.reflect.Array").newInstance(createObject("Java", "java.lang.Class").forName(arguments.typeName), arguments.size) />
    <cfreturn NewArray />
  </cffunction>

  <cffunction name="setJavaArray" access="public" hint="I set an element in a java array." output="false" returntype="void">
    <cfargument name="javaArray" hint="I am the Java Array to set an element of." required="yes" type="any" />
    <cfargument name="element" hint="I am the element in the array to set." required="yes" type="numeric" />
    <cfargument name="value" hint="I am the value to set the array element to." required="yes" type="any" />
    <cfset createObject("java", "java.lang.reflect.Array").set(arguments.javaArray, JavaCast("int", arguments.element), arguments.value) />
  </cffunction>

	<cffunction name="zipExport" output="false" description="Fetch a log of a given revision" returntype="query">
		<cftry>
			<cfscript>
				zipExport = createObject("java",'vershen.export.Exporter');
				dumpvar(zipExport.exportZip("wee"));
			</cfscript>
			<cfif not isDefined('logEntries')>
				<cfset logentries ="Java Err!">
			</cfif>
		<cfcatch><cfdump var="#cfcatch#"><cfabort></cfcatch>
		</cftry>
		<cfdump var="#logEntries#">
		<cfabort>
	</cffunction>

		
</cfcomponent>