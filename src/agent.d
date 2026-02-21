/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;

struct Agent {
  bool verbose = false;
  mtmd_context* ctx_vision;
  mtmd_bitmap*[] pendingBitmaps = [];
}

__gshared Agent agent = Agent();
