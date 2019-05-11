module RemiTodo

	using Dates
	using InlineExports
	using JSON
	using DataStructures

	const SAVEPATH = occursin("cache", first(Base.DEPOT_PATH)) ? abspath(Base.DEPOT_PATH[2], "config", "RemiTodo") : abspath(Base.DEPOT_PATH[1], "config", "RemiTodo")

	mutable struct Tag
		name    ::Symbol
		tot_time::Period
	end
	Tag(name::Symbol) = Tag(name, zero(Millisecond))

	mutable struct Item
		name      ::Symbol
		descr     ::String
		tags      ::Vector{Tag}
		tot_time  ::Millisecond
		start_time::Union{Nothing, DateTime}
	end

	Item(name::Symbol, descr::String, tags::Vector{Tag}) =
		Item(name, descr, tags, zero(Millisecond), nothing)

	isactive(i::Item) = i.start_time != nothing

	@export workon(i::Item)  = i.start_time = now()

	@export function workoff(i::Item)
		worked_time = now() - i.start_time
		i.tot_time += worked_time
		for t in i.tags
			t.tot_time += worked_time
		end
		i.start_time = nothing
	end


	mutable struct TodoList
		name  ::Symbol
		items ::Vector{Item}
		tags  ::Vector{Tag}
		function TodoList(n::Symbol, i::Vector{Item}, t::Vector{Tag})
			out = new(n, i, t)
			# We don't want to lose time that was already spent when things go wrong,
			# which is hopefully done by saving everything when this gets free'd.
			finalizer(free!, out)
		end
	end
	@export TodoList(name::Symbol) = TodoList(name, Item[], Tag[])

	active_items(l::TodoList) = filter(isactive, l.items)

	function free!(l::TodoList)
		for i in active_items(l)
			workoff(i)
		end
		save_list(l)
	end

	@export function save_list(l::TodoList)
		open(joinpath(SAVEPATH, "$(l.name).todo"), "w") do f
			write(f, json(l))
		end
	end

	@export function load_list(name::Union{Symbol, <:AbstractString})
		d = JSON.parsefile(joinpath(SAVEPATH, "$name.todo"))
		list = TodoList(Symbol(name))
		items = Item[]
		tags  = Tag[]
		for t in d["tags"]
			push!(list.tags, Tag(Symbol(t["name"]), Millisecond(t["tot_time"]["value"])))
		end

		for i in d["items"]
			push!(list.items, Item(Symbol(i["name"]), i["descr"], [tag(list, Symbol(v["name"])) for v in i["tags"]], Millisecond(i["tot_time"]["value"] ), nothing))
		end
		return list
	end

	Base.getindex(l::TodoList, i)         = getindex(l.items, i)
	Base.getindex(l::TodoList, i::Symbol) = getindex(l.items, itemid(l, i))

	Base.length(l::TodoList) = length(l.items)

	Base.size(l::TodoList) = (length(l), ) 

	tagid(l::TodoList, name::Symbol) = findfirst(x -> x.name == name, l.tags)

	itemid(l::TodoList, name::Symbol) = findfirst(x -> x.name == name, l.items)

	@export function tag(l::TodoList, name::Symbol)
		id = tagid(l, name)
		@assert id != nothing "Tag with name $name is not in TodoList $(l.name)."
		return l.tags[id]
	end

	@export function add_tag!(list::TodoList, name::Symbol)
	    f = tagid(list, name)
		@assert f == nothing "Tag with name $name already exists in the TodoList."
		t = Tag(name)
		push!(list.tags, t)
		return t
	end

	@export function item(l::TodoList, name::Symbol)
		id = itemid(l, name)
		@assert id != nothing "Item with name $name is not in TodoList $(l.name)."
		return l.items[id]
	end

	@export function add_item!(list::TodoList, name::Symbol, descr::String, tags::Symbol...)
		f = itemid(list, name)
		@assert f == nothing "Item with name $name already exists in the TodoList."

		itemtags = Tag[] 
		for tname in tags
			tid = tagid(list, tname)
			if tid == nothing
				@info "Tag with name $tname was not yet in TodoList $(list.name)\n\t Adding new Tag."
				push!(itemtags, add_tag!(list, tname))
			else
				push!(itemtags, list.tags[tid])
			end
		end
		it = Item(name, descr, itemtags)
		push!(list.items, it)
		return it
	end

end

