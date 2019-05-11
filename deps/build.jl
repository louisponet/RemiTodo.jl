
const SAVEPATH = occursin("cache", first(Base.DEPOT_PATH)) ? abspath(Base.DEPOT_PATH[2], "config", "ToDoTimer") : abspath(Base.DEPOT_PATH[1], "config", "ToDoTimer")
if !ispath(SAVEPATH)
	mkpath(SAVEPATH)
end
