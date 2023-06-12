###
# Bitwuzla: Satisfiability Modulo Theories (SMT) solver.
#
# This file is part of Bitwuzla.
#
# Copyright (C) 2007-2022 by the authors listed in the AUTHORS file.
#
# See COPYING for more information on using this software.
##
#
# Generate pybitwuzla_enums.pxd from bitwuzla.h
#
# Usage: mkenums.py path/to/bitwuzla.h path/to/outputfile
#

import sys
import os
import re
from collections import OrderedDict


class BitwuzlaEnumParseError(Exception):
    def __init__(self, bzla_enum):
        self.message = "Failed to parse bitwuzla.h when handling enum '{:s}'".format(
            bzla_enum
        )
        super(Exception, self).__init__(self.message)


def extract_enums(header):
    """
    Given the file "bitwuzla.h", constructs a dictionary representing the set
    of all Bitwuzla enums and corresponding values
    """

    # We want to get only non-empty, stripped lines from our input file
    lines = [
        line
        for line in [line.strip() for line in open(header, "r").readlines()]
        if line
    ]

    # Manually create an iterator as we want to be able to move this forwards ourselves
    line_iter = iter(lines)

    # Dictionary of all our enums and their values
    bzla_enums = OrderedDict()

    # For each line ...
    for line in line_iter:

        # Do we see the _start_ of an enum?
        if line.startswith("enum Bitwuzla"):

            # Obtain the enum name by splitting the line and taking the second
            # part
            enum_name = line.split(" ")[1]

            # Get the next line
            line = next(line_iter)

            # We expect this to be an opening curly, given Bitwuzla's style
            if line != "{":
                raise BitwuzlaEnumParseError(enum_name)

            # List to collect up all of the enum values for this enum
            enum_vals = []

            # Keep iterating until our line starts with the closing curly
            while not line.startswith("};"):

                # Find enum value in line starting with prefix `BITWUZLA_`.
                line_values = re.findall(r'^(BITWUZLA_[A-Z_]+)', line)
                assert len(line_values) <= 1
                if line_values:
                    enum_vals.extend(line_values)

                # Consume the next line
                line = next(line_iter)

            # Store this enum with its associated set of values
            bzla_enums[enum_name] = enum_vals

    # Return our dictionary of enums
    return bzla_enums


# Template for one enum
C_ENUM_TEMPLATE = """
    cdef enum {bzla_enum:s}:
        {values:s}
"""

PY_ENUM_TEMPLATE = """
class {bzla_enum:s}(Enum):
    \"\"\"{docstring:s}
    \"\"\"
    {values:s}
"""

# Template for the whole file
FILE_TEMPLATE = """from enum import Enum

cdef extern from \"bitwuzla.h\":
{cenums:s}

{pyenums:s}"""

ENUM_DOCSTRINGS = {
    "Option":
"""Configuration options supported by Bitwuzla. For more information on
   options see :ref:`c_options`.
""",

    "Kind":
"""BitwuzlaTerm kinds. For more information on term kinds see :ref:`c_kinds`.
""",

    "Result":
"""Satisfiability result.
""",

    "RoundingMode":
"""Floating-point rounding mode.
"""
}


def generate_output(bzla_enums, output_file):
    """
    Given a dictionary of enums, formats each enum into `C_ENUM_TEMPLATE` and
    then all the enums into `FILE_TEMPLATE` and writes into "output_file"
    """

    # List of strings for all our enums
    all_c_enums = []
    all_py_enums = []

    # Iterate on each enum and its associated values
    for bzla_enum, values in bzla_enums.items():

        # Construct the formatted list of all values
        formatted_c_values = ",\n        ".join(values)

        # Construct the C enum string
        s = C_ENUM_TEMPLATE.format(
            bzla_enum=bzla_enum, values=formatted_c_values
        )
        all_c_enums.append(s)


        #  Construct the Python enum string

        # We do not need to export BitwuzlaBVBase enums
        if bzla_enum == 'BitwuzlaBVBase':
            continue
        py_enum_name = bzla_enum.replace('Bitwuzla', '')
        py_values = []
        for e in values:
            py_e = e.replace('BITWUZLA_', '')
            for prefix in ('BV_BASE_', 'OPT_', 'KIND_', 'RM_'):
                if py_e.startswith(prefix):
                    py_e = py_e.replace(prefix, '', 1)
                    break
            if e not in ('BITWUZLA_RM_MAX', 'BITWUZLA_NUM_KINDS',
                         'BITWUZLA_OPT_NUM_OPTS'):
                py_values.append('{} = {}'.format(py_e, e))

        formatted_py_values = "\n    ".join(py_values)
        if py_enum_name not in ENUM_DOCSTRINGS:
            raise BitwuzlaEnumParseError(
                    f'Missing docstring for enum {py_enum_name}')
        docstring = ENUM_DOCSTRINGS[py_enum_name]
        s = PY_ENUM_TEMPLATE.format(
            bzla_enum=py_enum_name,
            docstring=docstring,
            values=formatted_py_values
        )
        all_py_enums.append(s)

    # Open-up our output file
    with open(output_file, "w") as output_fd:

        # Write the whole template
        output_fd.write(FILE_TEMPLATE.format(
            cenums="\n".join(all_c_enums),
            pyenums="\n".join(all_py_enums)
            ))


def main():
    """
    Entry point
    """

    # We expect to only have three arguments
    if len(sys.argv) != 3:
        raise ValueError("invalid number of arguments")

    # Script arguments
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # We expect our last argument to be a file 'bitwuzla.h'
    if os.path.basename(output_file) == "bitwuzla.h":
        raise ValueError("bitwuzla.h not specified")

    # Extract all of our enums
    bzla_enums = extract_enums(input_file)

    # Generate our output file
    generate_output(bzla_enums, output_file)

    return 0


if __name__ == "__main__":
    sys.exit(main())

# EOF
