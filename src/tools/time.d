/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import std.conv : to;
import std.datetime;
import std.format : format;

import tools : Tool, RegisterTools;

mixin RegisterTools;

@Tool("The current date and time in ISO 8601 format (YYYY-MM-DD HH:MM:SS)")
string currentTime() {
  try {
    return Clock.currTime().toISOExtString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The current Unix timestamp")
string currentTimestamp() {
  try {
    return to!string(Clock.currTime().toUnixTime());
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The current date in YYYY-MM-DD format")
string currentDate() {
  try {
    return Clock.currTime().toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("The day of the week for a date (YYYY-MM-DD) (mon, tue, wed, etc.)")
string dayOfWeek(string date) {
  try {
    auto dt = Date.fromISOExtString(date);
    return to!string(dt.dayOfWeek);
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Add or subtract days from any date (YYYY-MM-DD). A positive number adds, A negative subtracts. Returns the date in YYYY-MM-DD format.")
string addDays(string date, string days) {
  try {
    int numDays = to!int(days);
    auto dt = Date.fromISOExtString(date);
    auto newDate = dt + dur!"days"(numDays);
    return newDate.toISOExtString()[0..10];
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Calculate the number of days between two dates (format: YYYY-MM-DD). Positive if date2 is after date1, negative otherwise.")
string daysBetween(string date1, string date2) {
  try {
    auto d1 = Date.fromISOExtString(date1);
    auto d2 = Date.fromISOExtString(date2);
    auto diff = d2 - d1;
    return to!string(diff.total!"days");
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Check if a date (YYYY-MM-DD) is in the 'Past' or 'Future'.")
string isDatePast(string date) {
  try {
    auto checkDate = Date.fromISOExtString(date);
    auto today = cast(Date)Clock.currTime();
    return checkDate < today ? "Past" : "Future";
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}

@Tool("Format a Unix timestamp to human-readable date and time")
string formatTimestamp(string timestamp) {
  try {
    long ts = to!long(timestamp);
    auto dt = SysTime.fromUnixTime(ts);
    return dt.toISOExtString();
  } catch (Exception e) { return(format("Error: %s", e.msg)); }
}
