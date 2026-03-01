/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.algorithm : count;
import std.conv : to;
import std.format : format;
import std.string : split, strip;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("Count the number of words in text.")
string countWords(string text) {
  try {
    return to!string(text.strip().split().length);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Count how many times substring appears in text.")
string nOccurrences(string text, string substring) {
  try {
    return to!string(text.count(substring));
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Returns the number of characters in a word.")
string wordLength(string word) {
  try {
    return to!string(word.strip().length);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
