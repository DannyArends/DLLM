/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.file : readText;
import std.format : format;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Read the contents of a file.")
string readFile(string path) {
  try { return readText(path);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
