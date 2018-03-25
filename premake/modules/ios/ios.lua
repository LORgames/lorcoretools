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

	filter { "action:xcode4", "system:ios" }
		xcodebuildsettings {
			["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = "iPhone Developer",
			['IPHONEOS_DEPLOYMENT_TARGET'] = '8.1',
			['SDKROOT'] = 'iphoneos',
			['TARGETED_DEVICE_FAMILY'] = "1,2",
		}

	filter {}
