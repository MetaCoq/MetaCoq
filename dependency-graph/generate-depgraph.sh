#!/bin/bash

###############################################################
#
# Usage:
# In the dependency-graph folder, [generate-dpegraph.sh myname]
# produces [myname.dot] and [myname.svg].
#
# Example:
# cd dependency-graph
# ./generate-depgraph.sh depgraph-2020-09-24
#
###############################################################


filename=$1
dot_file=$filename.dot

# Associative arrays of the folders together with a color
declare -A folders
folders[template-coq]=aquamarine
folders[checker]=seagreen3
folders[pcuic]=lemonchiffon1
folders[safechecker]=paleturquoise1
folders[erasure]=tan

# Two first lines
echo "digraph dependencies {" > $dot_file
echo "node[style=filled]" >> $dot_file

for folder in "${!folders[@]}"
do
    cd ../$folder
    coqdep -f _CoqProject -dumpgraph ../dependency-graph/$folder.dot > /dev/null
    cd ../dependency-graph
    # remove the first and last lines
    sed -i '1d' $folder.dot
    sed -i '$d' $folder.dot
    # change a bit the names of the nodes
    for otherfolder in "${!folders[@]}"
    do
	sed -i "s@../$otherfolder/theories@$otherfolder@g" $folder.dot
    done
    sed -i "s/theories/$folder/g" $folder.dot
    # change the color of the nodes
    sed -i "s/]/, color=${folders[$folder]}]/g" $folder.dot
    # concatenate
    cat $folder.dot >> $dot_file
    rm -f $folder.dot
done

# remove duplicate lines
awk '!a[$0]++' $dot_file > $dot_file.tmp && mv $dot_file.tmp $dot_file

# last line
echo "}" >> $dot_file

# produce the svg file
dot -Tsvg $dot_file -o $filename.svg
