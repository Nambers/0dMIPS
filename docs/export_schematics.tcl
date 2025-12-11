set output_dir "./schematic_svgs"
file mkdir $output_dir

current_instance
write_schematic -format svg -scope all -force "${output_dir}/TOP.svg"
puts "\[00\] TOP (.)"


set other_cells [get_cells -hierarchical -filter {TYPE == Others}]

set exported [dict create]
# ban some huge module
dict set exported "data_mem" 1
dict set exported "cache_L1" 1
set idx 1

foreach cell $other_cells {
    set ref [get_property REF_NAME $cell]
    
    if {[dict exists $exported $ref]} continue
    dict set exported $ref 1
    
    set inst_path [get_property NAME $cell]
    set clean_name [regsub -all {[/\[\]:]} $ref "_"]
    
    if {[catch {current_instance $inst_path} err]} {
        puts "\[SKIP\] $ref - Cannot set as current instance"
        continue
    }
    
    # show_schematic [get_nets -hier]
    show_schematic [get_nets]
    write_schematic -format svg -scope all -force "${output_dir}/${clean_name}.svg"
    
    puts "\[[format %02d $idx]\] $ref (instance: $inst_name)"
    incr idx
    
    current_instance
}

current_instance

puts " Exported [expr $idx - 1] unique modules"
puts "  Location: [file normalize $output_dir]"
