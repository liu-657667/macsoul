#!/usr/bin/env python3
"""Deterministic Xcode project for the checked-in Swift sources; no external generator."""
from pathlib import Path
import hashlib
sources = sorted(Path('MacSoul').rglob('*.swift'))
tests = sorted(Path('MacSoulTests').rglob('*.swift'))
def oid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key, body): return f'{oid(key)} /* {key} */ = {{ {body} }};'
objects=[]
for path in sources+tests:
    key=str(path)
    objects.append(obj('file:'+key, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;'))
    objects.append(obj('build:'+key, f'isa = PBXBuildFile; fileRef = {oid("file:"+key)};'))
for folder, files in [('MacSoul',sources),('MacSoulTests',tests)]:
    refs=' '.join(f'{oid("file:"+str(p))},' for p in files)
    objects.append(obj('group:'+folder, f'isa = PBXGroup; children = ({refs}); path = {folder}; sourceTree = "<group>";'))
objects.append(obj('group:root',f'isa = PBXGroup; children = ({oid("group:MacSoul")}, {oid("group:MacSoulTests")}, {oid("product:app")}, {oid("product:tests")},); sourceTree = "<group>";'))
objects.append(obj('product:app','isa = PBXFileReference; explicitFileType = wrapper.application; path = MacSoul.app; sourceTree = BUILT_PRODUCTS_DIR;'))
objects.append(obj('product:tests','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MacSoulTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;'))
for name,files in [('app',sources),('tests',tests)]:
    refs=' '.join(f'{oid("build:"+str(p))},' for p in files)
    objects.append(obj('phase:'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({refs}); runOnlyForDeploymentPostprocessing = 0;'))
objects.append(obj('proxy:app',f'isa = PBXContainerItemProxy; containerPortal = {oid("project")}; proxyType = 1; remoteGlobalIDString = {oid("target:app")}; remoteInfo = MacSoul;'))
objects.append(obj('dependency:app',f'isa = PBXTargetDependency; target = {oid("target:app")}; targetProxy = {oid("proxy:app")};'))
for name,ptype,prod,phase,configs in [('app','com.apple.product-type.application','app','app','app'),('tests','com.apple.product-type.bundle.unit-test','tests','tests','tests')]:
    deps = f"dependencies = ({oid('dependency:app')},);" if name == 'tests' else 'dependencies = ();'
    objects.append(obj('target:'+name,f'isa = PBXNativeTarget; buildConfigurationList = {oid("configs:"+configs)}; buildPhases = ({oid("phase:"+phase)},); buildRules = (); {deps} name = {"MacSoul" if name=="app" else "MacSoulTests"}; productName = {"MacSoul" if name=="app" else "MacSoulTests"}; productReference = {oid("product:"+prod)}; productType = "{ptype}";'))

base='MACOSX_DEPLOYMENT_TARGET = 13.0; SWIFT_VERSION = 5.0; SDKROOT = macosx; CODE_SIGNING_ALLOWED = NO; GENERATE_INFOPLIST_FILE = YES;'
for name in ('app','tests'):
    for kind in ('Debug','Release'):
        extra=('PRODUCT_BUNDLE_IDENTIFIER = local.macsoul.app; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.developer-tools";' if name=='app' else 'PRODUCT_BUNDLE_IDENTIFIER = local.macsoul.tests; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/MacSoul.app/Contents/MacOS/MacSoul"; BUNDLE_LOADER = "$(TEST_HOST)";')
        objects.append(obj(f'config:{name}:{kind}',f'isa = XCBuildConfiguration; buildSettings = {{ {base} {extra} PRODUCT_NAME = "$(TARGET_NAME)"; ENABLE_TESTABILITY = YES; SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if kind=="Debug" else "-O"}; }}; name = {kind};'))
    objects.append(obj('configs:'+name,f'isa = XCConfigurationList; buildConfigurations = ({oid("config:"+name+":Debug")}, {oid("config:"+name+":Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;'))
for kind in ('Debug','Release'):
    objects.append(obj('config:project:'+kind,f'isa = XCBuildConfiguration; buildSettings = {{ MACOSX_DEPLOYMENT_TARGET = 13.0; SWIFT_VERSION = 5.0; }}; name = {kind};'))
objects.append(obj('configs:project',f'isa = XCConfigurationList; buildConfigurations = ({oid("config:project:Debug")}, {oid("config:project:Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;'))
objects.append(obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; TargetAttributes = {{ {oid("target:app")} = {{ CreatedOnToolsVersion = 27.0; }}; {oid("target:tests")} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {oid("target:app")}; }}; }}; }}; buildConfigurationList = {oid("configs:project")}; compatibilityVersion = "Xcode 15.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {oid("group:root")}; productRefGroup = {oid("group:root")}; projectDirPath = ""; projectRoot = ""; targets = ({oid("target:app")}, {oid("target:tests")},);'))
text='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {oid("project")}; }}\n'
project=Path('MacSoul.xcodeproj/project.pbxproj')
if project.exists() and project.read_text()!=text:
    raise SystemExit('project differs; refusing overwrite (review changes before regeneration)')
project.write_text(text)
