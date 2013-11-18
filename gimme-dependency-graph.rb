#!/usr/bin/env ruby

require "optparse"
require "graph"

$exclude_dir_pattern = /etc|src|test|tests|node_modules|build/
$include_filename_pattern = /\.js$/
$dependency_line = /we7.Gimme\s*\(['"]([^'"]+)['"]\s*,(?:\s*\[\s*([^\]]*)\s*\]\s*,)?\s*function\s*\(/

$options = {
	:root_colour => "forestgreen",
	:node_colour => "white",
	:undefined_colour => "orangered",
	:invert => false
}

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: "+File.basename($0)+" [options] root_dir"

	# General options
	opts.on("-m", "--module [MODULENAME]", "Root module to trace dependencies for (omit to map all dependencies in system)") do |val|
		$options[:module] = val
	end

	opts.on("-i", "--invert", "Trace all modules that have a dependency on the module defined with --module (instead of all modules which this module depends on)") do ||
		$options[:invert] = true
	end

	opts.on("-e", "--exclude-modules [MODULENAMES]", "Do not trace dependencies on these modules (comma-separated list)") do |val|
		$options[:exclude_modules] = val.nil? ? [] : val.split(/\s*,\s*/)
	end

	opts.on("-o", "--output-image [IMAGENAME]", "Output image name") do |val|
		$options[:output_image] = val
	end

	# Formatting options
	opts.on("-r", "--root-colour [COLOURNAME]", "Show root nodes (nodes with no dependencies) in this colour.  Use the --show-colours option to get a list of valid colours") do |val|
		$options[:root_colour] = val
	end

	# Formatting options
	opts.on("-n", "--node-colour [COLOURNAME]", "Show normal (non-root) nodes in this colour.  Use the --show-colours option to get a list of valid colours") do |val|
		$options[:node_colour] = val
	end

	# Formatting options
	opts.on("-u", "--undefined-colour [COLOURNAME]", "Show nodes marked as dependencies but not defined anywhere in the code in this colour.  Use the --show-colours option to get a list of valid colours") do |val|
		$options[:undefined_colour] = val
	end

	# Misc. information
	opts.on("-s", "--show-colours", "Output a list of valid colours") do |val|
		$options[:show_colours] = val
	end

end.parse!

if $options[:show_colours]
	puts (Graph::BOLD_COLORS + Graph::LIGHT_COLORS).sort.join("\n")
	exit
end

if !$options[:exclude_modules]
	if !$options[:module]	# If we haven't specified a module and we haven't specified an exclude pattern, default to excluding common modules
		$options[:exclude_modules] = ["Wez", "Templates", "Events", "PageConfig", "Log", "Page"]
	else
		$options[:exclude_modules] = []
	end
end

if ARGV[0] && File.exist?(ARGV[0])	# && root_dir = File.absolute_path(ARGV[0])
	root_dir = Dir.new(ARGV[0].chomp("/"))
end

if !root_dir
	puts "Must provide a valid, existing directory to work on"
	exit 1
end


def recursive_get_files(dir)
	files = []
	dir.each do |filename|
		next if (filename[0] == ".") || ([".", ".."].include? filename)
		filepath = dir.path+"/"+filename
		if File.directory?(filepath) && !filepath.match($exclude_dir_pattern)
			child_dir = Dir.new(filepath)
			#puts "Recursing into #{filepath}"
			files += recursive_get_files(child_dir)
		elsif filename.match($include_filename_pattern)
			file = File.new(filepath)
			files << filepath
			#puts "\t-> #{filepath}"
		end
	end
	return files
end

def scan_file(filepath)
	modules = {}
	File.open(filepath) do |file|
		contents = file.read
		matches = contents.scan($dependency_line)
		matches.each do |match|
			if match[1]
				raw_dependency_string = match[1]
				raw_dependency_string.gsub!(/\/\/[^\n]*\n/m, "")
				dependencies = (raw_dependency_string.strip.split(/\s*,\s*/).collect do |dependency| dependency[1..-2] end)
			else
				dependencies = []
			end
			
			#puts ">#{match[0]}\t\t=> #{dependencies.join("|")}\t\t\t(#{filepath})"
			if modules[match[0]].nil?
				modules[match[0]] = dependencies || []
			else
				puts "\tWarning! Duplicate definition found for module #{match[0]} in file #{filepath}: may have dependencies #{modules[match[0]]} or #{dependencies}"
				modules[match[0]] = (modules[match[0]] + dependencies).uniq	# Merge dependencies
			end
		end
	end
	return modules
end

def get_roots(modules)
	root_modules = []
	modules.each do |modname, deps|
		root_modules << modname if deps.empty?
	end
	return root_modules
end

def build_digraph(modules, root_module_name)
	if root_module_name.nil?	# No root module specified, so just spit out the entire module map
		def processnode(modules, modname, deps, colours)
			if !($options[:exclude_modules].include? modname)
				if !nodes.has_key?(modname)
					newnode = node(modname)
					if modules[modname].empty?
						colours[:root] << newnode	# Colour root nodes (nodes with no dependencies) green
					end
				end

				deps.each do |depname|
					if !($options[:exclude_modules].include? depname)
						newnode = node(depname)
						if !modules[depname] || modules[depname].empty?
							colours[:root] << newnode	# Colour root nodes (nodes with no dependencies) green
						end
						newedge = edge(modname, depname)
					end
				end
			end
		end
		return digraph do
			colours = {
				:root => fillcolor($options[:root_colour]),
				:node => fillcolor($options[:node_colour]),
				:undefined => fillcolor($options[:undefined_colour])
			}
			node_attribs << filled
			node_attribs << colours[:node]
			modules.each do |modulename, deps|
				processnode(modules, modulename, deps, colours)
			end
		end
	else	# Root node specified, so recursively trawl through its dependencies and build the map from those
		def processnode(modules, modname, deps, parentname, colours)
			if !nodes.has_key?(modname)
				newnode = node(modname)
				if !modules.has_key?(modname)
					colours[:undefined] << newnode
				elsif modules[modname].empty?
					colours[:root] << newnode
				end
			end
			edge(parentname, modname) unless parentname.nil?
			deps.each do |depname|
				if !($options[:exclude_modules].include? depname)
					processnode(modules, depname, modules[depname] || [], modname, colours)
				end
			end
		end
		return digraph do
			colours = {
				:root => fillcolor($options[:root_colour]),
				:node => fillcolor($options[:node_colour]),
				:undefined => fillcolor($options[:undefined_colour])
			}
			node_attribs << filled
			node_attribs << colours[:node]
			processnode(modules, root_module_name, modules[root_module_name], nil, colours)
		end
	end
end

def build_digraph_inverted(modules, root_module_name)
end

def output_text(modules, root_module_name)
	if root_module_name
		modules = { root_module_name => modules[root_module_name] }
	end
	longestmodname = modules.keys.reduce { |memo, obj| obj.length > memo.length ? obj : memo }
	modules.each do |modname, deps|
		puts "#{modname.ljust(longestmodname.length)} [#{deps.join(', ')}]"
	end
end

def output_text_inverted(modules, root_module_name)
	

	modules.each do |modname, deps|
		if deps.include? root_module_name
			puts modname;
		end
	end
	
#	longestmodname = modules.keys.reduce { |memo, obj| obj.length > memo.length ? obj : memo }
#	modules.each do |modname, deps|
#		puts "#{modname.ljust(longestmodname.length)} [#{deps.join(', ')}]"
#	ends
end

def output_digraph_image(graph, basename)
	graph.save basename, "png"
	puts "Wrote graph image to #{basename}.png"
end

puts "Scanning #{root_dir.path}:"
files = recursive_get_files root_dir
puts "\tdone"
puts "----------\n"

puts "Collating module dependencies:"
modules = {}
files.each do |file|
	modules_in_file = scan_file(file)
	modules.merge!(modules_in_file) do |key, oldval, newval|
		puts "\tWarning! Duplicate definition found for module #{key}: may have dependencies #{oldval} or #{newval}"
		(oldval + newval).uniq	# Merge dependencies
	end
end
root_modules = get_roots(modules)
puts "\tRoot modules (modules with no dependencies of their own):"
puts "\t\t#{root_modules.join(', ')}"
puts "\tExcluding modules:"
puts "\t\t#{$options[:exclude_modules].join(', ')}"
puts "\tdone"
puts "----------\n"

if $options[:output_image].nil?
	if $options[:invert] == false
		output_text(modules, $options[:module])
	else
		output_text_inverted(modules, $options[:module])
	end
elsif $options[:output_image]
	puts "Building directed graph:"
	if $options[:invert] == false
		graph = build_digraph(modules, $options[:module])
	else
		graph = build_digraph_inverted(modules, $options[:module])
	end
	puts "\tdone"
	puts "----------\n"
	output_digraph_image(graph, $options[:output_image])
end

