gimme-dependency-graph
======================

Scan a codebase that uses our internal Gimme framework and automatically generate reports and graphs of module dependencies.

Usage
-----

    Usage: gimme-dependency-graph.rb [options] root_dir

    -m, --module [MODULENAME]        Root module to trace dependencies for (omit to map all dependencies in system)
    -i, --invert                     Trace all modules that have a dependency on the module defined with --module (instead of all modules which this module depends on)
    -e [MODULENAMES],                Do not trace dependencies on these modules (comma-separated list)
        --exclude-modules
    -o, --output-image [IMAGENAME]   Output image name
    -r, --root-colour [COLOURNAME]   Show root nodes (nodes with no dependencies) in this colour.  Use the --show-colours option to get a list of valid colours
    -n, --node-colour [COLOURNAME]   Show normal (non-root) nodes in this colour.  Use the --show-colours option to get a list of valid colours
    -u [COLOURNAME],                 Show nodes marked as dependencies but not defined anywhere in the code in this colour.  Use the --show-colours option to get a list of valid colours
        --undefined-colour
    -s, --show-colours               Output a list of valid colours`