<!---
	 $Id: DefaultXmlBeanFactory.cfc,v 1.6 2005/09/24 18:50:43 rossd Exp $
---> 

<cfcomponent name="DefaultXmlBeanFactory" 
			displayname="DefaultXmlBeanFactory" 
			extends="coldspring.beans.AbstractBeanFactory"
			hint="XML Bean Factory implimentation" 
			output="false">
			
	<!--- local struct to hold bean definitions --->
	<cfset variables.beanDefs = structnew()/>
	
	<cffunction name="init" access="public" returntype="coldspring.beans.DefaultXmlBeanFactory" output="false">
		<cfreturn this />
	</cffunction>
	
	<cffunction name="loadBeans" access="public" returntype="void" output="false">
		<cfargument name="beanDefinitionFileName" type="string" required="true" />
		<!--- add args for method of resource loading --->
		
		<cfset var cffile = 0/>
		<cfset var rawBeanDefXML = ""/>
		
		<cffile action="read" 
					file="#arguments.beanDefinitionFileName#"	 
					variable="rawBeanDefXML"/>
					
		<cfset loadBeanDefinitions(xmlParse(rawBeanDefXML))/>
		
	</cffunction>
	
	<cffunction name="loadBeanDefinitions" access="public" returntype="void">
		<cfargument name="XmlBeanDefinitions" type="string" required="true" 
					hint="I am a parsed Xml file of bean definitions"/>
					
		<cfset var beans = 0 />
		<cfset var beanDef = 0 />
		<cfset var beanIx = 0 />
		<cfset var beanAttributes = 0 />
		<cfset var beanChildren = 0 />
		<cfset var isSingleton = true />

		<!--- <cfset var beanChildIx = 0 />
		<cfset var beanChild = 0 /> --->
		
		<cfif isDefined("arguments.XmlBeanDefinitions.beans.bean")>
			<cfset beans = arguments.XmlBeanDefinitions.beans.bean>
		<cfelse>
			<cfthrow type="coldspring.XmlParserException" message="Xml file contains no beans!">
		</cfif>
		
		<!--- create bean definition objects for each bean in config file --->
		<cfloop from="1" to="#ArrayLen(beans)#" index="beanIx">
			
			<cfset beanAttributes = beans[beanIx].XmlAttributes />
			<cfset beanChildren = beans[beanIx].XmlChildren />
			
			<cfif not (StructKeyExists(beanAttributes,'id') and StructKeyExists(beanAttributes,'class'))>
				<cfthrow type="coldspring.MalformedBeanException" message="Xml bean definitions must contain 'id' and 'class' attributes!">
			</cfif>
			
			<!--- <cfdump var="#beanAttributes#"><cfabort>			
			<cfif StructKeyExists(beanAttributes,'singleton')>
				<cfset isSingleton = beanAttributes.singleton />
			<cfelse>
				<cfset isSingleton = true />
			</cfif> --->
			
			<!--- <cftry> --->
				<!--- call function to create bean definition and add to store --->
				<cfset createBeanDefinition(beanAttributes.id, beanAttributes.class, beanChildren, isSingleton, false) />
			
			<!--- 	<cfcatch>
						<cfthrow type="coldspring.BeanDefinitionCreationException" message="Error occured creating bean: #beanAttributes.class# (#cfcatch.message#)">
				</cfcatch>
		
			</cftry>
		 --->	
		</cfloop>
		
		
		
	</cffunction>
	
	<cffunction name="createBeanDefinition" access="public" returntype="void" output="false">
		<cfargument name="beanID" type="string" required="true" />
		<cfargument name="beanClass" type="string" required="true" />
		<cfargument name="children" type="any" required="true" />
		<cfargument name="isSingleton" type="boolean" required="true" />
		<cfargument name="isInnerBean" type="boolean" required="true" />
		
		<cfset var childIx = 0 />
		<cfset var child = '' />
	
		<!--- construct a bean definition file for this bean --->
		<cfset variables.beanDefs[arguments.beanID] = 
				   	CreateObject('component', 'coldspring.beans.BeanDefinition').init(this) />
		
		<cfset variables.beanDefs[arguments.beanID].setBeanID(arguments.beanID) />
		<cfset variables.beanDefs[arguments.beanID].setBeanClass(arguments.beanClass) />
		<cfset variables.beanDefs[arguments.beanID].setSingleton(arguments.isSingleton) />
		<cfset variables.beanDefs[arguments.beanID].setInnerBean(arguments.isInnerBean) />
		
		<!--- set up property readers for this beanDefinition --->
		<cfloop from="1" to="#ArrayLen(arguments.children)#" index="childIx">
			<cfset child = arguments.children[childIx] />
			<cfif child.XmlName eq "property">
				<cfset variables.beanDefs[arguments.beanID].addProperty(createObject("component","coldspring.beans.BeanProperty").init(child, variables.beanDefs[arguments.beanID]))/>
			</cfif>
			<cfif child.XmlName eq "constructor-arg">
				<cfset variables.beanDefs[arguments.beanID].addConstructorArg(createObject("component","coldspring.beans.BeanProperty").init(child, variables.beanDefs[arguments.beanID]))/>
			</cfif>			
		</cfloop>
		
	</cffunction>
	

	<cffunction name="containsBean" access="public" output="false" returntype="boolean"
				hint="returns true if the BeanFactory contains a bean definition or bean instance that matches the given name">
		<cfargument name="beanName" required="true" type="string" hint="name of bean to look for"/>
		<cfreturn structKeyExists(variables.beanDefs, arguments.beanName)/>
	</cffunction>
	
	<cffunction name="isSingleton" access="public" returntype="boolean" output="false">
		<cfargument name="beanName" type="string" required="true" />
		<cfif containsBean(arguments.beanName)>
			<cfreturn variables.beanDefs[arguments.beanName].isSingleton() />
		<cfelse>
			<cfthrow type="coldspring.NoSuchBeanDefinitionException" detail="Bean definition for bean named: #arguments.beanName# could not be found."/>
		</cfif>
	</cffunction>
	
	<cffunction name="getBean" access="public" output="false" returntype="any" 
				hint="returns an instance of the bean registered under the given name. Depending on how the bean was configured by the BeanFactory configuration, either a singleton and thus shared instance or a newly created bean will be returned. A BeansException will be thrown when either the bean could not be found (in which case it'll be a NoSuchBeanDefinitionException), or an exception occurred while instantiating and preparing the bean">
		<cfargument name="beanName" required="true" type="string" hint="name of bean to look for"/>
		
		<cfif containsBean(arguments.beanName)>
			<cfif variables.beanDefs[arguments.beanName].isSingleton()>
				<cfif variables.beanDefs[arguments.beanName].isConstructed()>
					<!--- <cfreturn getBeanFromSingletonCache(arguments.beanName) > --->
					<cfreturn variables.beanDefs[arguments.beanName].getInstance() />
				<cfelse>
					<!--- lazy-init happens here --->
					<cfset constructBean(arguments.beanName)/>	
				</cfif>
				<cfreturn variables.beanDefs[arguments.beanName].getInstance() />
			<cfelse>
				<!--- return a new instance of this bean def --->
				<cfreturn constructBean(arguments.beanName,true)/>
			</cfif>				
		<cfelse>
			<cfthrow type="coldspring.NoSuchBeanDefinitionException" detail="Bean definition for bean named: #arguments.beanName# could not be found."/>
		</cfif>		
		
	</cffunction>
	
	<cffunction name="constructBean" access="private" returntype="any">
		<cfargument name="beanName" type="string" required="true"/>
		<cfargument name="returnInstance" type="boolean" required="false" default="false" 
					hint="true when constructing a non-singleton bean (aka a prototype)"/>
					
		<!--- first get list of beans including this bean and it's dependencies --->
		<cfset var localBeanCache = StructNew() />
		<cfset var dependentBeanDefs = ArrayNew(1) />
		<cfset var dependentBeanNames = getBeanDefinition(arguments.beanName).getDependencies(arguments.beanName) />
		<cfset var beanDefIx = 0 />
		<cfset var beanDef = 0 />
		<cfset var beanInstance = 0 />
		<cfset var dependentBeanDef = 0 />
		<cfset var dependentBeanInstance = 0 />
		<cfset var propDefs = 0 />
		<cfset var prop = 0/>
		<cfset var argDefs = 0 />
		<cfset var arg = 0/>
		<cfset var md = '' />
		<cfset var functionIndex = '' />
		
		<!--- put them all in an array, and while we're at it, make sure they're in the singleton cache, or the localbean cache --->
		<cfloop from="1" to="#ListLen(dependentBeanNames)#" index="beanDefIx">
			<cfset beanDef = getBeanDefinition(ListGetAt(dependentBeanNames,beanDefIx)) />
			<cfset ArrayAppend(dependentBeanDefs,beanDef) />
			<cfif beanDef.isSingleton() and not(singletonCacheContainsBean(beanDef.getBeanID()))>
				<cfset addBeanToSingletonCache(beanDef.getBeanID(), beanDef.getBeanInstance() ) /> <!--- CreateObject('component', beanDef.getBeanClass())) /> --->
			<cfelse>
				<cfset localBeanCache[beanDef.getBeanID()] = beanDef.getBeanInstance() /> <!--- CreateObject('component', beanDef.getBeanClass()) /> --->
			</cfif>
		</cfloop>
		
		<!--- now resolve all dependencies  --->
		<cfloop from="1" to="#ArrayLen(dependentBeanDefs)#" index="beanDefIx">
			<cfset beanDef = dependentBeanDefs[beanDefIx] />
			
			<cfif not beanDef.isConstructed()>
				<cfif beanDef.isSingleton()>
					<cfset beanInstance = getBeanFromSingletonCache(beanDef.getBeanID())>
				<cfelse>
					<cfset beanInstance = localBeanCache[beanDef.getBeanID()] />
				</cfif>
				
				<cfset argDefs = beanDef.getConstructorArgs()/>
				
				<cfset propDefs = beanDef.getProperties()/>
				
				<cfset md = getMetaData(beanInstance)/>
				
				<!--- we need to call init method if it exists --->
				<cfloop from="1" to="#arraylen(md.functions)#" index="functionIndex">
					<cfif md.functions[functionIndex].name eq "init">
						<cfinvoke component="#beanInstance#" method="init">
							<!--- loop over any bean constructor-args and pass them into the init() --->
							<cfloop collection="#argDefs#" item="arg">
								<cfswitch expression="#argDefs[arg].getType()#">
									<cfcase value="value">
										<cfinvokeargument name="#argDefs[arg].getName()#"
												    	  value="#argDefs[arg].getValue()#"/>
									</cfcase>

									<cfcase value="list,map">
										<cfinvokeargument name="#argDefs[arg].getName()#"
												    	  value="#constructComplexProperty(argDefs[arg].getValue(),argDefs[arg].getType(), localBeanCache)#"/>
									</cfcase>
									
									<cfcase value="ref,bean">
										<cfset dependentBeanDef = getBeanDefinition(argDefs[arg].getValue()) />
										<cfif dependentBeanDef.isSingleton()>
											<cfset dependentBeanInstance = getBeanFromSingletonCache(dependentBeanDef.getBeanID())>
										<cfelse>
											<cfset dependentBeanInstance = localBeanCache[dependentBeanDef.getBeanID()] />
										</cfif>
										<cfinvokeargument name="#argDefs[arg].getName()#"
														  value="#dependentBeanInstance#"/>
									</cfcase>		
									
																				  
								</cfswitch> 				  								
							</cfloop>
						</cfinvoke>
						<cfbreak />
					</cfif>
				</cfloop>
				
				<!--- if this is a bean that extends the factory bean, set is factory --->
				<cfif ArrayLen(StructFindValue(md,"coldspring.beans.factory.FactoryBean","ALL"))>
					<cfset beanDef.setIsFactory(true) />
					<cfset beanInstance.setBeanFactory(this) />
				</cfif>
				<!---
				do we need to make sure that value is in the extends key??
				--->
				
				<!--- now do dependency injection via setters --->		
				<cfloop collection="#propDefs#"	item="prop">
					<cfswitch expression="#propDefs[prop].getType()#">
						<cfcase value="value">
							<cfinvoke component="#beanInstance#"
									  method="set#propDefs[prop].getName()#">
								<cfinvokeargument name="#propDefs[prop].getName()#"
									  	value="#propDefs[prop].getValue()#"/>
							</cfinvoke>					
						</cfcase>
						
						<cfcase value="map,list">
							<cfinvoke component="#beanInstance#"
									  method="set#propDefs[prop].getName()#">
								<cfinvokeargument name="#propDefs[prop].getName()#"
									  	value="#constructComplexProperty(propDefs[prop].getValue(), propDefs[prop].getType(), localBeanCache)#"/>
							</cfinvoke>					
						</cfcase>
						
						<cfcase value="ref,bean">
							<cfset dependentBeanDef = getBeanDefinition(propDefs[prop].getValue()) />
							<cfif dependentBeanDef.isSingleton()>
								<cfset dependentBeanInstance = getBeanFromSingletonCache(dependentBeanDef.getBeanID())>
							<cfelse>
								<cfset dependentBeanInstance = localBeanCache[dependentBeanDef.getBeanID()] />
							</cfif>
							<cfinvoke component="#beanInstance#"
									  method="set#propDefs[prop].getName()#">
								<cfinvokeargument name="#propDefs[prop].getName()#"
												  value="#dependentBeanInstance#"/>
							</cfinvoke>
						</cfcase>		
					</cfswitch>
				
				</cfloop>
				
				<cfif beanDef.isSingleton()>
					<cfset beanDef.setIsConstructed(true)/>
				</cfif>
			</cfif>
			
		</cfloop>
		
		<!--- if we're supposed to return the new object, do it --->
		<cfif arguments.returnInstance>
			<cfif dependentBeanDefs[1].isSingleton()>
				<cfreturn getBeanFromSingletonCache(dependentBeanDefs[1].getBeanID())>
			<cfelse>
				<cfreturn localBeanCache[dependentBeanDefs[1].getBeanID()]>
			</cfif>	
		</cfif>	
		
	</cffunction>	
	
	<cffunction name="getBeanDefinition" access="public" returntype="coldspring.beans.BeanDefinition" output="false">
		<cfargument name="beanName" type="string" required="true" />
		<cfif not StructKeyExists(variables.beanDefs, beanName)>
			<cfthrow type="coldspring.MissingBeanReference" message="There is no bean registered with the factory with the id #arguments.beanName#" />
		<cfelse>
			<cfreturn variables.beanDefs[arguments.beanName] />
		</cfif>
	</cffunction>
	
	<cffunction name="getBeanDefinitionList" access="public" returntype="Struct" output="false">
		<cfreturn variables.beanDefs />
	</cffunction>
	
	<cffunction name="singletonCacheContainsBean" access="public" returntype="boolean" output="false">
		<cfargument name="beanName" type="string" required="true" />
		<cfset var objExists = 0 />
		<cflock name="SingletonCache" type="readonly" timeout="5">
			<cfset objExists = StructKeyExists(variables.singletonCache, beanName) />
		</cflock>
		<cfreturn objExists />
	</cffunction>
	
	<cffunction name="getBeanFromSingletonCache" access="public" returntype="any" output="false">
		<cfargument name="beanName" type="string" required="true" />
		<cfset var objRef = 0 />
		<cfset var error = false />
		<cflock name="SingletonCache" type="readonly" timeout="5">
			<cfif StructKeyExists(variables.singletonCache, beanName)>
				<cfset objRef = variables.singletonCache[beanName] />
			<cfelse>
				<cfset error = true />
			</cfif>
		</cflock>
		
		<cfif error>
			<cfthrow message="Cache error, #beanName# does not exists">
		<cfelse>
			<cfreturn objRef />
		</cfif>
	</cffunction>
	
	<cffunction name="addBeanToSingletonCache" access="public" returntype="any" output="false">
		<cfargument name="beanName" type="string" required="true" />
		<cfargument name="beanObject" type="any" required="true" />
		<cfset var error = false />
		
		<cflock name="SingletonCache" type="exclusive" timeout="5">
			<cfif StructKeyExists(variables.singletonCache, beanName)>
				<cfset error = true />
			<cfelse>
				<cfset variables.singletonCache[beanName] = beanObject />
			</cfif>
		</cflock>
		
		<cfif error>
			<cfthrow message="Cache error, #beanName# already exists in cache">
		</cfif>
	</cffunction>



	<cffunction name="constructComplexProperty" access="private" output="false" returntype="any">
		<cfargument name="ComplexProperty" type="any" required="true"/>
		<cfargument name="type" type="string" required="true"/>
		<cfargument name="localBeanCache" type="struct" required="true"/>
		<cfset var rtn = 0 />	
		
		<cfif arguments.type eq 'map'>
			<!--- just return the struct because it's passed by ref --->
			<cfset findComplexPropertyRefs(arguments.ComplexProperty,arguments.type, arguments.localBeanCache)/> 
			<cfreturn arguments.ComplexProperty/>		
		<cfelseif arguments.type eq 'list'>
			<!--- tail recursion for the array (and return the result) --->			
			<cfreturn findComplexPropertyRefs(arguments.ComplexProperty,arguments.type, arguments.localBeanCache)/> 			
		</cfif>
		
		
	</cffunction>
	
	<cffunction name="findComplexPropertyRefs" access="private" output="false" returntype="any">
		<cfargument name="ComplexProperty" type="any" required="true"/>	
		<cfargument name="type" type="string" required="true"/>
		<cfargument name="localBeanCache" type="struct" required="true"/>
		<cfset var entry=0/>
		<cfset var tmp_ref=0/>
		
		<cfswitch expression="#arguments.type#">
			<cfcase value="map">
				<cfloop collection="#arguments.ComplexProperty#" item="entry">					
					<cfif isObject(arguments.ComplexProperty[entry]) and getMetaData(arguments.ComplexProperty[entry]).name eq "coldspring.beans.BeanReference">
						<cfset dependentBeanDef = getBeanDefinition(arguments.ComplexProperty[entry].getBeanID()) />
						<cfif dependentBeanDef.isSingleton()>
							<cfset arguments.ComplexProperty[entry] = getBeanFromSingletonCache(dependentBeanDef.getBeanID())>
						<cfelse>
							<cfset arguments.ComplexProperty[entry] = localBeanCache[dependentBeanDef.getBeanID()] />
						</cfif>						
					<cfelseif isStruct(arguments.ComplexProperty[entry])>
						<cfset findComplexPropertyRefs(arguments.ComplexProperty[entry],"map",arguments.localBeanCache)/>
					<cfelseif isArray(arguments.ComplexProperty[entry])>
						<cfset arguments.ComplexProperty[entry] = findComplexPropertyRefs(arguments.ComplexProperty[entry],"list",arguments.localBeanCache)/>						
					</cfif>	
				</cfloop>	
			</cfcase>
			<cfcase value="list">
				<cfloop from="1" to="#arraylen(arguments.ComplexProperty)#" index="entry">
					<cfif isObject(arguments.ComplexProperty[entry]) and getMetaData(arguments.ComplexProperty[entry]).name eq "coldspring.beans.BeanReference">
						<cfset dependentBeanDef = getBeanDefinition(arguments.ComplexProperty[entry].getBeanID()) />
						<cfif dependentBeanDef.isSingleton()>
							<cfset arguments.ComplexProperty[entry] = getBeanFromSingletonCache(dependentBeanDef.getBeanID())>
						<cfelse>
							<cfset arguments.ComplexProperty[entry] = localBeanCache[dependentBeanDef.getBeanID()] />
						</cfif>						
					<cfelseif isStruct(arguments.ComplexProperty[entry])>
						<cfset findComplexPropertyRefs(arguments.ComplexProperty[entry],"map",arguments.localBeanCache)/>
					<cfelseif isArray(arguments.ComplexProperty[entry])>
						<cfset arguments.ComplexProperty[entry] = findComplexPropertyRefs(arguments.ComplexProperty[entry],"list",arguments.localBeanCache)/>
					</cfif>	
				</cfloop>			
				<cfreturn arguments.ComplexProperty />
			</cfcase>
		</cfswitch>
		
	</cffunction>


</cfcomponent>