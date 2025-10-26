local BuildTool={}
BuildTool._ENV=_ENV

-- 复制lua文件
function BuildTool.buildLuaResources(config,projectPath,outputPath)
  local luaLibsPaths={}
  local assetsPaths={}
  local include=config.include or {"project:app","project:androlua"}
  for index, content in ipairs(include) do
    local _type,name=content:match("(.-):(.+)")
    if _type=="project" then
      local libraryPath=projectPath.."/"..name
      local luaPath=libraryPath.."/src/main/luaLibs"
      local assetsPath=libraryPath.."/src/main/assets_bin"
      local luaFile=File(luaPath)
      local assetsFile=File(assetsPath)
      if luaFile.isDirectory() then
        table.insert(luaLibsPaths,luaFile)
      end
      if assetsFile.isDirectory() then
        table.insert(assetsPaths,assetsFile)
      end
    end
  end

  for index,content in ipairs(assetsPaths) do
    FileUtil.copyDir(content,File(outputPath.."/assets"))
  end
  for index,content in ipairs(luaLibsPaths) do
    FileUtil.copyDir(content,File(outputPath.."/lua"))
  end
end

---自动编译Lua (v5.1.1+)
---@param compileDir File 文件夹对象
function BuildTool.autoCompileLua(compileDir,onCompileListener)
  for index,content in ipairs(luajava.astable(compileDir.listFiles())) do
    local name=content.name
    if content.isDirectory() then
      BuildTool.autoCompileLua(content,onCompileListener)
     elseif name:find"%.lua$" then
      local path=content.getPath()
      local func,err=loadfile(path)
      if func then
        io.open(path,"w"):write(string.dump(func,true)):close()
       else
        if onCompileListener and onCompileListener.onError then
          onCompileListener.onError("Compilation failed "..err)
        end
      end
      func=nil
      path=nil
     elseif name:find"%.aly$" then
      local path=content.getPath()
      local func,err=loadfile(path)
      local path=path:match("(.+)%.aly")..".lua"
      if func then
        io.open(path,"w")
        :write(string.dump(func,true))
        :close()
       else
        if onCompileListener and onCompileListener.onError then
          onCompileListener.onError("Compilation failed "..err)
        end
      end
      content.delete()
      func=nil
      path=nil
     elseif name==".nomedia" or name==".outside" or name==".hidden" then
      content.delete()
      if onCompileListener and onCompileListener.onDeleted then
        onCompileListener.onDeleted("Deleted "..content.getPath())
      end
    end
  end
end

-- 预打包 lua 资源
function BuildTool.preBuild(config, projectPath)
  local outputPath = projectPath .. "/app/build/temp-androlua"
  -- 清理构建目录
  LuaUtil.rmDir(File(outputPath))
  -- 复制 lua 资源文件
  BuildTool.buildLuaResources(config, projectPath, outputPath)
  -- 编译 lua
  local isCompileLua = type(config.compileLua) == "nil" and getSharedData("compileLua") or config.compileLua
  if isCompileLua then
    BuildTool.autoCompileLua(File(outputPath), nil)
  end
end

return BuildTool