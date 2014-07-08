#! /home/aananth/bin/python2.7

import os.path
import re


class Node(object):

    def __init__(self, name):
        self._name = name
        self._children = {}

    def add_child(self, name, node):
        self._children[name] = node

    def get_child(self, name):
        try:
            c = self._children[name]
        except KeyError:
            print self._children
            print name
            exit(0)
        else:
            return c

    def myname(self):
        return self._name

class VerilogFilelist(Node):

    def __init__(self, path):
        self._path = self._normalize_path(path)
        self.parsed_contents = []

        super(VerilogFilelist, self).__init__(path)       

        self._parse()

    def _parse(self):

        print "Parsing: %s" % self._path

        # Read File list
        try:
            flist_FR = open(self._path, 'r')
        except IOError:
            raise Exception(
                    """
                    File list <%s> is unreadable.
                    Nested file list found in [%s]
                    """ % (self._path, self.myname())
                )
        else:
            filelist_contents = flist_FR.readlines()

        # Parse contents
        for line in filelist_contents:

            if re.match(r'\s*\/\/', line):
                self.parsed_contents.append(line)

            elif re.match(r'\s*-f\s+.+?\.f', line):

                path = re.match(r'\s*-f\s+(.+?\.f)', line).group(1)

                print "Found %s" % path

                path = self._normalize_path(path)

                child_flist = VerilogFilelist(path)

                self.add_child(child_flist.myname(), child_flist)

                marker = self._get_marker(path)

                self.parsed_contents.append(marker)

            else:
                self.parsed_contents.append(line)

    def _normalize_path(self, path):

       # Expand env variables
       expanded_path = os.path.expandvars(path)
       # Expand symbolic links
       expanded_path = os.path.realpath(expanded_path)

       return expanded_path   

    def _get_marker(self, path):
       return "// FLIST %s//" % path

    def flatten(self):
        flattened_content = []

        # Check if any filelists nested else return the list of all file list lines
        if not re.search(r"// FLIST", "".join(self.parsed_contents), re.DOTALL):
            return self.parsed_contents

        # Search lines for file lists, this is done
        # linewise as to keep the order in which the 
        # filelist is specified.
        for line in self.parsed_contents:

            # Search for flist
            match = re.match(r"// FLIST (.+?)//", line)

            if match:
                # Get flist path
                flist = match.group(1)

                # Get flist contents and add it to parent flist
                for line in self.get_child(flist).flatten():
                    # Add lines to content
                    flattened_content.append(line)

            else:
                flattened_content.append(line)

        return flattened_content

    def get_content(self, hide_dupe):

        # Get content
        flat_content = self.flatten()

        # remove duplicate module references
        content_list = self._remove_duplicates(
            hide_dupe=hide_dupe,
            content_list=flat_content
        )

        return "".join(content_list)

    def generate_output(self, hide_dupe=False, outfile=None):

        if not outfile:
            outfile = "flat_%s" % self._path

        content = self.get_content(hide_dupe)

        try:
            output_filelist = open(outfile, 'w')
        except IOError:
            print "Error writing out file."
        else:
            output_filelist.write(content)
            print "Successfuly wrote out file %s" % outfile
            output_filelist.close()

            
    def _remove_duplicates(self, hide_dupe, content_list):

        uniq_list=[]
        for line in content_list:

            if not re.match(r'\s*\/\/', line) and line in uniq_list and not re.match(r'\s*\n\s*', line):
                if not hide_dupe:
                    uniq_list.append("//DUPE//%s" % line)
            else:
                uniq_list.append(line)

        return uniq_list

if __name__ == '__main__':
    import sys
    import argparse 

    parser = argparse.ArgumentParser(description='Flatten Verilog Filelist.')
    parser.add_argument("--infile", help="Flatten filelist at specified path.")
    parser.add_argument("--outfile", help="Generate filelist at output path.")
    parser.add_argument("--hide_dupe", help="Remove duplicate paths.")
    args = parser.parse_args()

    if (len(sys.argv) == 1):
        print """
            Please enter the filelist path as argument.
            Use "-h" for help.
            Usage: %s [-h] <filelist path>
        """ % sys.argv[0]
        sys.exit(1)

    VF = VerilogFilelist(args.infile)
    VF.generate_output(
            hide_dupe=args.hide_dupe,
            outfile=args.outfile
    )

    

