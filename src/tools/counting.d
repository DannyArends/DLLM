/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */
module counting;

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

unittest {
  import utils : check;
  check(countWords("hello world"),  "2", "countWords: basic");
  check(countWords("  spaced  "),   "1", "countWords: strips whitespace");
  check(countWords("one two three"),"3", "countWords: three words");
  check(countWords(""),             "0", "countWords: empty string");

  check(nOccurrences("banana", "an"), "2", "nOccurrences: multiple");
  check(nOccurrences("hello",  "z"),  "0", "nOccurrences: no match");
  check(nOccurrences("aaa",    "aa"), "1", "nOccurrences: non-overlapping");

  check(wordLength("hello"),   "5", "wordLength: basic");
  check(wordLength("  hi  "),  "2", "wordLength: strips whitespace");
  check(wordLength(""),        "0", "wordLength: empty");
}

