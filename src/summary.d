/** 
 * Authors: Danny Arends
 * License: GPL-v3 (See accompanying file LICENSE.txt or copy at https://www.gnu.org/licenses/gpl-3.0.en.html)
 */

import includes;
import utils;

import model : LlamaModel;

struct Summary {
  LlamaModel model;               /// Model pointer
  alias model this;
}
