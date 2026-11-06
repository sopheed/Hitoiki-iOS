#!/usr/bin/env python3
"""Generate the Xcode project, including iPhone-only AdMob packages, with stable IDs."""
from pathlib import Path
import hashlib, json, plistlib
root = Path(__file__).resolve().parents[1]
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_key, **values):
    objects[uid(object_key)] = values
    return uid(object_key)
def config_list(name, settings):
    configs=[]
    for c in ['Debug','Release']:
        s = settings.copy()
        s.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if c=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if c=='Debug' else 'dwarf-with-dsym'})
        if c=='Debug': s['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'
        configs.append(add(name+c,isa='XCBuildConfiguration',buildSettings=s,name=c))
    return add(name+'ConfigList',isa='XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
shared=add('SharedGroup',isa='PBXFileSystemSynchronizedRootGroup',path='Shared',sourceTree='<group>')
ad_config=add('AdvertisingConfig',isa='PBXFileReference',lastKnownFileType='text.xcconfig',path='Configuration/Advertising.xcconfig',sourceTree='<group>')
ad_packages=[]; ad_products=[]; ad_builds=[]
for package,product,version in [('google-mobile-ads','GoogleMobileAds','13.12.0'),('google-user-messaging-platform','GoogleUserMessagingPlatform','3.1.0')]:
    reference=add(package+'Package',isa='XCRemoteSwiftPackageReference',repositoryURL='https://github.com/googleads/swift-package-manager-'+package+'.git',requirement={'kind':'exactVersion','version':version})
    dependency=add(package+'Product',isa='XCSwiftPackageProductDependency',package=reference,productName=product)
    ad_packages.append(reference); ad_products.append(dependency)
    ad_builds.append(add(package+'Build',isa='PBXBuildFile',productRef=dependency))
target_names=['Hitoiki','HitoikiWatch','HitoikiTests','HitoikiUITests']
products=[]; groups=[shared,ad_config]
for name in target_names:
    groups.append(add(name+'Group',isa='PBXFileSystemSynchronizedRootGroup',path=name,sourceTree='<group>'))
    test='Tests' in name
    product=add(name+'Product',isa='PBXFileReference',explicitFileType='wrapper.cfbundle' if test else 'wrapper.application',includeInIndex=0,path=name+('.xctest' if test else '.app'),sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    phases=[]
    for phase in ['Sources','Frameworks','Resources']:
        phases.append(add(name+phase,isa='PBX'+phase+'BuildPhase',buildActionMask=2147483647,files=ad_builds if name=='Hitoiki' and phase=='Frameworks' else [],runOnlyForDeploymentPostprocessing=0))
    deps=[]
    if name=='Hitoiki':
        embed=add('WatchEmbedFile',isa='PBXBuildFile',fileRef=uid('HitoikiWatchProduct'),settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
        phases.append(add('EmbedWatch',isa='PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='$(CONTENTS_FOLDER_PATH)/Watch',dstSubfolderSpec=16,files=[embed],name='Embed Watch Content',runOnlyForDeploymentPostprocessing=0))
    dependency = 'HitoikiWatch' if name=='Hitoiki' else 'Hitoiki' if test else None
    if dependency:
        proxy=add(name+'Proxy',isa='PBXContainerItemProxy',containerPortal=uid('Project'),proxyType=1,remoteGlobalIDString=uid(dependency+'Target'),remoteInfo=dependency)
        deps.append(add(name+'Dependency',isa='PBXTargetDependency',target=uid(dependency+'Target'),targetProxy=proxy))
    settings={
        'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'eijirou.'+name.replace('HitoikiWatch','Hitoiki.watchkitapp'),
        'CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'TQQM6G5CS8','GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0',
        'IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1',
        'SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator',
        'CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0',
        'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks',
    }
    if not test:
        settings.update({'CURRENT_PROJECT_VERSION':'2','MARKETING_VERSION':'1.0.1'})
        settings.update({'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','INFOPLIST_FILE':'Configuration/'+name+'-Info.plist','INFOPLIST_KEY_CFBundleDisplayName':'ひといき'})
    if name=='Hitoiki':
        settings.update({'INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait','ENABLE_PREVIEWS':'YES'})
    if name=='HitoikiWatch':
        settings.update({'SDKROOT':'watchos','SUPPORTED_PLATFORMS':'watchos watchsimulator','WATCHOS_DEPLOYMENT_TARGET':'10.0','TARGETED_DEVICE_FAMILY':'4','SKIP_INSTALL':'YES'})
    if name=='HitoikiTests':
        settings.update({'BUNDLE_LOADER':'$(TEST_HOST)','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Hitoiki.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Hitoiki'})
    if name=='HitoikiUITests': settings['TEST_TARGET_NAME']='Hitoiki'
    configs=config_list(name,settings)
    if name=='Hitoiki':
        for config in ['Debug','Release']: objects[uid(name+config)]['baseConfigurationReference']=ad_config
    add(name+'Target',isa='PBXNativeTarget',buildConfigurationList=configs,buildPhases=phases,buildRules=[],dependencies=deps,fileSystemSynchronizedGroups=[uid(name+'Group')]+([shared] if not test else []),packageProductDependencies=ad_products if name=='Hitoiki' else [],name=name,productName=name,productReference=product,productType='com.apple.product-type.bundle.ui-testing' if name=='HitoikiUITests' else 'com.apple.product-type.bundle.unit-test' if test else 'com.apple.product-type.application')
product_group=add('Products',isa='PBXGroup',children=products,name='Products',sourceTree='<group>')
main=add('Main',isa='PBXGroup',children=groups+[product_group],sourceTree='<group>')
project_config=config_list('Project',{'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17','GCC_WARN_UNINITIALIZED_AUTOS':'YES_AGGRESSIVE','SWIFT_STRICT_CONCURRENCY':'targeted','ENABLE_USER_SCRIPT_SANDBOXING':'YES','SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_TESTABILITY':'YES'})
add('Project',isa='PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2710','TargetAttributes':{uid(n+'Target'):{'CreatedOnToolsVersion':'27.1',**({'TestTargetID':uid('HitoikiTarget')} if 'Tests' in n else {})} for n in target_names}},buildConfigurationList=project_config,compatibilityVersion='Xcode 16.0',developmentRegion='ja',knownRegions=['ja','en','Base'],mainGroup=main,preferredProjectObjectVersion=77,productRefGroup=product_group,projectDirPath='',projectRoot='',packageReferences=ad_packages,targets=[uid(n+'Target') for n in target_names])
def serialize(value,indent=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(indent+1)+json.dumps(k,ensure_ascii=False)+' = '+serialize(v,indent+1)+';\n' for k,v in value.items())+'\t'*indent+'}'
    if isinstance(value,list): return '( '+', '.join(serialize(v,indent) for v in value)+(' , ' if value else '')+')'
    if isinstance(value,int): return str(value)
    return json.dumps(value,ensure_ascii=False)
project={'archiveVersion':1,'classes':{},'objectVersion':77,'objects':objects,'rootObject':uid('Project')}
(root/'Hitoiki.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize(project)+'\n')
for name in ['Hitoiki','HitoikiWatch']:
    def ref(n): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(n+"Target")}" BuildableName="{n}.{"xctest" if "Tests" in n else "app"}" BlueprintName="{n}" ReferencedContainer="container:Hitoiki.xcodeproj"/>'
    testables=''.join(f'<TestableReference skipped="NO">{ref(n)}</TestableReference>' for n in ['HitoikiTests','HitoikiUITests']) if name=='Hitoiki' else ''
    scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(name)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testables}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(name)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(name)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
    (root/f'Hitoiki.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme').write_text(scheme)
info_path=root/'Configuration/Hitoiki-Info.plist'
info=plistlib.loads(info_path.read_bytes()) if info_path.exists() else {}
info.update({'NSCameraUsageDescription':'今の景色やお水を撮って、ひといきの記録に残すためにカメラを使います。','ITSAppUsesNonExemptEncryption':False,'LSApplicationCategoryType':'public.app-category.healthcare-fitness','GADApplicationIdentifier':'$(ADMOB_APP_ID)','BannerAdUnitIdentifier':'$(ADMOB_BANNER_ID)','GADDelayAppMeasurementInit':True,'ChildDirectedAdvertising':False})
(root/'Configuration/Hitoiki-Info.plist').write_bytes(plistlib.dumps(info))
watch={'WKApplication':True,'WKCompanionAppBundleIdentifier':'eijirou.Hitoiki','WKRunsIndependentlyOfCompanionApp':False,'ITSAppUsesNonExemptEncryption':False}
(root/'Configuration/HitoikiWatch-Info.plist').write_bytes(plistlib.dumps(watch))
privacy={'NSPrivacyTracking':False,'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[]}
for n in ['Hitoiki','HitoikiWatch']:
    (root/n/'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print('Generated Hitoiki.xcodeproj and shared schemes')
