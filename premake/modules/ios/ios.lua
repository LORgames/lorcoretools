--
-- Name:        ios/ios.lua
-- Purpose:     Define the iOS APIs
-- Author:      Samuel Surtees
-- Copyright:   (c) 2015 Samuel Surtees and the Premake project
--

require "xcode"

	local p = premake
	local api = p.api
  local project = p.project
  local tree = p.tree
  local fileconfig = p.fileconfig
  local config = p.config

--
-- Register the IOS extension
--

	p.IOS = "ios"

	api.addAllowed("system", { p.IOS })
	api.addAllowed("architecture", { p.ARM })

--
-- Override xcode4 functions
--

	local function xcodePrintUserConfigReferences(offset, cfg, tr, kind)
		local referenceName
		if kind == "project" then
			referenceName = cfg.xcodeconfigreferenceproject
		elseif kind == "target" then
			referenceName = cfg.xcodeconfigreferencetarget
		end
		tree.traverse(tr, {
			onleaf = function(node)
				filename = node.name
				if node.id and path.getextension(filename) == ".xcconfig" then
					if filename == referenceName then
						_p(offset, 'baseConfigurationReference = %s /* %s */;', node.id, filename)
						return
					end
				end
			end
		}, false)
	end
  
  
  
	local escapeSpecialChars = {
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
	}
  
	local function escapeChar(c)
		return escapeSpecialChars[c] or '\\'..c
	end
  
	local function escapeArg(value)
		value = value:gsub('[\'"\\\n\r\t ]', escapeChar)
		return value
	end
  
	local function escapeSetting(value)
		value = value:gsub('["\\\n\r\t]', escapeChar)
		return value
	end
  
	local function stringifySetting(value)
		value = value..''
		if not value:match('^[%a%d_./]+$') then
			value = '"'..escapeSetting(value)..'"'
		end
		return value
	end
  
	local function customStringifySetting(value)
		value = value..''
  
		local test = value:match('^[%a%d_./%+]+$')
		if test then
			value = '"'..escapeSetting(value)..'"'
		end
		return value
	end
  
	local function printSetting(level, name, value)
		if type(value) == 'function' then
			value(level, name)
		elseif type(value) ~= 'table' then
			_p(level, '%s = %s;', stringifySetting(name), stringifySetting(value))
		--elseif #value == 1 then
			--_p(level, '%s = %s;', stringifySetting(name), stringifySetting(value[1]))
		elseif #value >= 1 then
			_p(level, '%s = (', stringifySetting(name))
			for _, item in ipairs(value) do
				_p(level + 1, '%s,', stringifySetting(item))
			end
			_p(level, ');')
		end
	end
  
	local function printSettingsTable(level, settings)
		-- Maintain alphabetic order to be consistent
		local keys = table.keys(settings)
		table.sort(keys)
		for _, k in ipairs(keys) do
			printSetting(level, k, settings[k])
		end
	end
  
	local function overrideSettings(settings, overrides)
		if type(overrides) == 'table' then
			for name, value in pairs(overrides) do
				-- Allow an override to remove a value by using false
				settings[name] = iif(value ~= false, value, nil)
			end
		end
	end

p.override(p.modules.xcode, "PBXProject", function(oldfn, tr)
	if _OPTIONS["target"] == p.IOS then -- system is macosx...
    _p('/* Begin PBXProject section */')
		_p(2,'08FB7793FE84155DC02AAC07 /* Project object */ = {')
		_p(3,'isa = PBXProject;')
		_p(3,'attributes = {')
		_p(4,'LastUpgradeCheck = 0610;')
		_p(4,'TargetAttributes = {')
    _p(5,'%s = {', tr.id)
    _p(6,'CreatedOnToolsVersion = 6.1;')
    _p(5,'};')
		_p(4,'};')
		_p(3,'};')
		_p(3,'buildConfigurationList = 1DEB928908733DD80010E9CD /* Build configuration list for PBXProject "%s" */;', tr.name)
		_p(3,'compatibilityVersion = "Xcode 3.2";')
		_p(3,'hasScannedForEncodings = 1;')
		_p(3,'mainGroup = %s /* %s */;', tr.id, tr.name)
		_p(3,'projectDirPath = "";')
    
		if #tr.projects.children > 0 then
			_p(3,'projectReferences = (')
			for _, node in ipairs(tr.projects.children) do
				_p(4,'{')
				_p(5,'ProductGroup = %s /* Products */;', node.productgroupid)
				_p(5,'ProjectRef = %s /* %s */;', node.id, path.getname(node.path))
				_p(4,'},')
			end
			_p(3,');')
		end
    
		_p(3,'projectRoot = "";')
		_p(3,'targets = (')
		for _, node in ipairs(tr.products.children) do
			_p(4,'%s /* %s */,', node.targetid, node.name)
		end
		_p(3,');')
		_p(2,'};')
		_p('/* End PBXProject section */')
		_p('')
	else
		oldfn(tr)
	end
end)

p.override(p.modules.xcode, "XCBuildConfiguration_Target", function(oldfn, tr, target, cfg)
	if _OPTIONS["target"] == p.IOS then
  	local settings = {}

		settings['ALWAYS_SEARCH_USER_PATHS'] = 'NO'

		if not cfg.flags.Symbols then
			settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
		end

		if cfg.kind ~= "StaticLib" and cfg.buildtarget.prefix ~= '' then
			settings['EXECUTABLE_PREFIX'] = cfg.buildtarget.prefix
		end

		--[[if cfg.targetextension then
			local ext = cfg.targetextension
			ext = iif(ext:startswith('.'), ext:sub(2), ext)
			settings['EXECUTABLE_EXTENSION'] = ext
		end]]

		local outdir = path.getrelative(tr.project.location, path.getdirectory(cfg.buildtarget.relpath))
		if outdir ~= "." then
			settings['CONFIGURATION_BUILD_DIR'] = outdir
		end

		settings['GCC_DYNAMIC_NO_PIC'] = 'NO'

		if tr.infoplist then
			settings['INFOPLIST_FILE'] = config.findfile(cfg, path.getextension(tr.infoplist.name))
		end

		installpaths = {
			ConsoleApp = '/usr/local/bin',
			WindowedApp = '"$(HOME)/Applications"',
			SharedLib = '/usr/local/lib',
			StaticLib = '/usr/local/lib',
		}
		settings['INSTALL_PATH'] = installpaths[cfg.kind]

		local fileNameList = {}
		local file_tree = project.getsourcetree(tr.project)
		tree.traverse(tr, {
				onnode = function(node)
					if node.buildid and not node.isResource and node.abspath then
						-- ms this seems to work on visual studio !!!
						-- why not in xcode ??
						local filecfg = fileconfig.getconfig(node, cfg)
						if filecfg and filecfg.flags.ExcludeFromBuild then
						--fileNameList = fileNameList .. " " ..filecfg.name
							table.insert(fileNameList, escapeArg(node.name))
						end

						--ms new way
						-- if the file is not in this config file list excluded it from build !!!
						--if not cfg.files[node.abspath] then
						--	table.insert(fileNameList, escapeArg(node.name))
						--end
					end
				end
			})

		if not table.isempty(fileNameList) then
			settings['EXCLUDED_SOURCE_FILE_NAMES'] = fileNameList
		end
		settings['PRODUCT_NAME'] = cfg.buildtarget.basename

    settings["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = "iPhone Developer"
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '8.1'
    settings['SDKROOT'] = 'iphonesimulator'--'iphoneos'
    settings['TARGETED_DEVICE_FAMILY'] = "1,2"

		--ms not by default ...add it manually if you need it
		--settings['COMBINE_HIDPI_IMAGES'] = 'YES'

		overrideSettings(settings, cfg.xcodebuildsettings)

		_p(2,'%s /* %s */ = {', cfg.xcode.targetid, cfg.buildcfg)
		_p(3,'isa = XCBuildConfiguration;')
		_p(3,'buildSettings = {')
		printSettingsTable(4, settings)
		_p(3,'};')
		printSetting(3, 'name', cfg.buildcfg);
		_p(2,'};')
	else
		oldfn(tr, target, cfg)
	end
end)

--
-- Set global environment for the default WinRT platforms
--

	filter {}
