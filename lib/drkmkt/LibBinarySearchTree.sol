// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;


/*
* Red-Black Tree, modified from https://github.com/rob-Hitchens/OrderStatisticsTree
*/


library LibBinarySearchTree {
   uint private constant EMPTY = 0;


   struct Node {
       uint parent;
       uint left;
       uint right;
       bool red;
       uint256[] keys;
       mapping(uint256 => uint) keyMap;
       uint count;
   }


   struct Tree {
       uint root;
       mapping(uint => Node) nodes;
   }


   function first(Tree storage self) internal view returns (uint _value) {
       _value = self.root;
       if (_value == EMPTY) return 0;
       while (self.nodes[_value].left != EMPTY) {
           _value = self.nodes[_value].left;
       }
   }


   function last(Tree storage self) internal view returns (uint _value) {
       _value = self.root;
       if (_value == EMPTY) return 0;
       while (self.nodes[_value].right != EMPTY) {
           _value = self.nodes[_value].right;
       }
   }


   function getKeyIndex(Tree storage self, uint key, uint value) internal view returns (uint) {
       return self.nodes[value].keyMap[key];
   }


   function next(Tree storage self, uint key, uint value) internal view returns (uint _cursor) {
       require(value != EMPTY, "OrderStatisticsTree(401) - Starting value cannot be zero");
       _cursor = EMPTY;
       uint256 keyposition = self.nodes[value].keyMap[key];
       // First check if this value has any siblings, and use one if so.
       if (self.nodes[value].keys.length > 1 && keyposition < (self.nodes[value].keys.length - 1)) {
           // Go looking for siblings.
           for (uint i = keyposition + 1; i < self.nodes[value].keys.length; i++) {
               if (self.nodes[value].keys[i] != key) {
                   // Found a sibling!
                   _cursor = self.nodes[value].keys[i];
                   break;
               }
           }
       } else {
           if (self.nodes[value].right != EMPTY) {
               // There is a right for this, just use the value straight to the right.
               _cursor = treeMinimum(self, self.nodes[value].right);
           } else {
               _cursor = self.nodes[value].parent;
               // Move to the parent.
               while (_cursor != EMPTY && value == self.nodes[_cursor].right) {
                   // Look for cousins.
                   value = _cursor;
                   _cursor = self.nodes[_cursor].parent;
               }
           }


           if (_cursor != EMPTY) {
               _cursor = self.nodes[_cursor].keys[0];
           }
       }
   }


   /// @dev Return the key of the node at the Xth position back in the tree.
   function xPrev(Tree storage self, uint key, uint value, uint x) internal view returns (uint _cursor) {
       // Loop x times to find the Xth previous node.
       for (uint i = 0; i < x; i++) {
           _cursor = prev(self, key, value);
           if (_cursor == 0) {
               break;
           }
           value = _cursor;
           //key = self.nodes[value].keys[0];
       }
   }


   /// @dev Return the key of the node at the Xth position forward in the tree.
   function xNext(Tree storage self, uint key, uint value, uint x) internal view returns (uint _cursor) {
       // Loop x times to find the Xth next node.
       for (uint i = 0; i < x; i++) {
           _cursor = next(self, key, value);
           if (_cursor == 0) {
               break;
           }
           value = _cursor;
           //key = self.nodes[value].keys[0];
       }
   }


   // Returns the key of the value that is previous to this one.
   function prev(Tree storage self, uint key, uint value) internal view returns (uint _cursor) {
       require(value != EMPTY, "OrderStatisticsTree(402) - Starting value cannot be zero");
       _cursor = EMPTY;
       uint256 keyposition = self.nodes[value].keyMap[key];
       // First check if this value has any siblings, and use one if so.
       if (self.nodes[value].keys.length > 1 && keyposition > 0 && keyposition < (self.nodes[value].keys.length)) {
           // Go looking for siblings.
           for (uint i = keyposition; i >= 0; i--) {
               if (self.nodes[value].keys[i] != key) {
                   // Found a sibling!
                   _cursor = self.nodes[value].keys[i];
                   break;
               }
           }
       } else {
           if (self.nodes[value].left != EMPTY) {
               // There is a left for this, just use the value straight to the left.
               _cursor = treeMaximum(self, self.nodes[value].left);
           } else {
               // Otherwise, if there is no left value, then we should use the parent.
               _cursor = self.nodes[value].parent;
               while (_cursor != EMPTY && value == self.nodes[_cursor].left) {
                   // Go looking for cousins.
                   value = _cursor;
                   _cursor = self.nodes[_cursor].parent;
               }
           }


           if (_cursor != EMPTY) {
               // Since we are going left, we need to get the value of the last one.
               _cursor = self.nodes[_cursor].keys[self.nodes[_cursor].keys.length - 1];
           }
       }
   }


   function exists(Tree storage self, uint value) internal view returns (bool _exists) {
       if (value == EMPTY) return false;
       if (value == self.root) return true;
       if (self.nodes[value].parent != EMPTY) return true;
       return false;
   }


   function keyExists(Tree storage self, uint256 key, uint value) internal view returns (bool _exists) {
       if (!exists(self, value)) return false;
       // Also make sure that the key is not outside of the range of the keys.
       if (self.nodes[value].keyMap[key] >= self.nodes[value].keys.length) return false;
       uint256 keyposition = self.nodes[value].keyMap[key];
       return self.nodes[value].keys[keyposition] == key;
   }


   function getRoot(Tree storage self) internal view returns (uint _root) {
       return self.root;
   }


   function getNode(
       Tree storage self,
       uint value
   ) internal view returns (uint _parent, uint _left, uint _right, bool _red, uint _keyCount, uint _count) {
       require(exists(self, value), "OrderStatisticsTree(403) - Value does not exist.");
       Node storage gn = self.nodes[value];
       return (gn.parent, gn.left, gn.right, gn.red, gn.keys.length, gn.keys.length + gn.count);
   }


   function getNodeAndKey(
       Tree storage self,
       uint value
   ) internal view returns (uint _parent, uint _left, uint _right, bool _red, uint _keyCount, uint _count, uint _key) {
       require(exists(self, value), "OrderStatisticsTree(403) - Value does not exist.");
       Node storage gn = self.nodes[value];
       return (gn.parent, gn.left, gn.right, gn.red, gn.keys.length, gn.keys.length + gn.count, gn.keys[0]);
   }


   function getNodeCount(Tree storage self, uint value) internal view returns (uint _count) {
       Node storage gn = self.nodes[value];
       _count = gn.keys.length + gn.count;
       return _count;
   }


   function valueKeyAtIndex(Tree storage self, uint value, uint index) internal view returns (uint256 _key) {
       require(exists(self, value), "OrderStatisticsTree(404) - Value does not exist.");
       return self.nodes[value].keys[index];
   }


   function count(Tree storage self) internal view returns (uint _count) {
       _count = getNodeCount(self, self.root);
       return _count;
   }


   function percentile(Tree storage self, uint value) internal view returns (uint _percentile) {
       uint denominator = count(self);
       uint numerator = rank(self, value);
       _percentile = ((uint(1000) * numerator) / denominator + (uint(5))) / uint(10);
   }


   function permil(Tree storage self, uint value) internal view returns (uint _permil) {
       uint denominator = count(self);
       uint numerator = rank(self, value);
       _permil = ((uint(10000) * numerator) / denominator + (uint(5))) / uint(10);
   }


   /// @dev Get the values and keys of X nodes to the left of the given rank, including the given rank.
   function xPrevValues(
       Tree storage self,
       uint value,
       uint x
   ) internal view returns (uint[] memory _values, uint[] memory _keys) {
       uint[] memory values = new uint[](x);
       uint[] memory keys = new uint[](x);
       uint cursor = value;
       for (uint i = 0; i < x; i++) {
           if (cursor == 0) {
               break;
           }
           values[i] = cursor;
           keys[i] = self.nodes[cursor].keys[0];
           cursor = prev(self, keys[i], cursor);
       }
       return (values, keys);
   }


   function atPercentile(Tree storage self, uint _percentile) internal view returns (uint _value) {
       uint findRank = (((_percentile * count(self)) / uint(10)) + uint(5)) / uint(10);
       (_value, ) = keyValueAtRank(self, findRank);
   }


   function atPermil(Tree storage self, uint _permil) internal view returns (uint _value) {
       uint findRank = (((_permil * count(self)) / uint(100)) + uint(5)) / uint(10);
       (_value, ) = keyValueAtRank(self, findRank);
   }


   function median(Tree storage self) internal view returns (uint value) {
       return atPercentile(self, 50);
   }


   function below(Tree storage self, uint value) public view returns (uint _below) {
       if (count(self) > 0 && value > 0) _below = rank(self, value) - uint(1);
   }


   function above(Tree storage self, uint value) public view returns (uint _above) {
       if (count(self) > 0) _above = count(self) - rank(self, value);
   }


   // This function calculates the rank of a given value within a binary search tree.
   // The rank is the number of values in the tree that are smaller than the given value.
   // The function takes a Tree storage variable and a uint value as parameters, and returns a uint value
   // representing the rank.
   function rank(Tree storage self, uint value) internal view returns (uint _rank) {
       if (count(self) > 0) {
           bool finished;
           uint cursor = self.root;
           Node storage c = self.nodes[cursor];
           uint totalToLeft = getNodeCount(self, c.left);


           // We use a while loop to traverse the tree.
           while (!finished) {
               // Get the old keycount.
               uint oldKeyCount = c.keys.length;


               // Get the node at the current cursor.
               c = self.nodes[cursor];
               // Get the number of keys in the current node.
               uint keyCount = c.keys.length;


               if (cursor == value) {
                   finished = true;
               } else {
                   if (cursor < value) {
                       cursor = c.right;
                       c = self.nodes[cursor];
                       uint256 nodeCount = getNodeCount(self, c.left);
                       // Add the number of nodes in the left subtree of the new node to the "totalToLeft" counter.
                       totalToLeft += oldKeyCount + nodeCount;
                   } else {
                       cursor = c.left;
                       c = self.nodes[cursor];
                       // We need to update the keyCount here.
                       keyCount = c.keys.length;
                       uint256 nodeCount = getNodeCount(self, c.right);
                       // Subtract the number of nodes in the right subtree of the new node from the "totalToLeft"
                       // counter.
                       if (totalToLeft >= (keyCount + nodeCount)) {
                           totalToLeft -= keyCount + nodeCount;
                       } else if (totalToLeft >= keyCount) {
                           totalToLeft -= keyCount;
                       } else {
                           finished = true;
                       }
                   }
               }


               // Check if the cursor has moved outside the bounds of the tree.
               if (!exists(self, cursor)) {
                   // If so, finish the loop.
                   finished = true;
               }
           }
           // Finally, we return the rank of the value within the tree.
           return totalToLeft + 1;
       }
   }


   // This function returns the node key at a specified rank in a binary tree.
   // It takes the tree object as a reference and the rank as a parameter.
   // It is an internal function, meaning it can only be called from within the contract.
   function keyValueAtRank(Tree storage self, uint _rank) internal view returns (uint _value, uint _key) {
       // Define a boolean flag to indicate when the function has finished searching the tree.
       bool finished;
       // Set the initial cursor to the root of the tree.
       uint cursor = self.root;
       // Get the node at the current cursor.
       Node storage c = self.nodes[cursor];
       // Calculate the number of nodes in the left subtree of the current node.
       uint totalToLeft = getNodeCount(self, c.left);
       // Start a loop that will continue until the function has found the node at the specified rank.
       while (!finished) {
           // Set the return value to the current cursor.
           _value = cursor;


           // Get the old keycount.
           uint oldKeyCount = c.keys.length;


           // Get the node at the current cursor.
           c = self.nodes[cursor];
           // Get the number of keys in the current node.
           uint keyCount = c.keys.length;


           // If the total count to the left is less than the rank, then the result is either in the current
           // node or in the right subtree. To determine which, we need to check if the rank is within the current
           // node, by checking if the rank is greater than the totalToLeft and less than the totalToLeft + keyCount.
           if (_rank > totalToLeft && _rank <= totalToLeft + keyCount) {
               _value = cursor;
               // The rank is within the current node, so we return the key at the specified rank.
               // Determine if we are going left or right.
               // The index of the key is the rank minus the totalToLeft minus 1.
               _key = c.keys[_rank - totalToLeft - 1];
               finished = true;
           } else {
               // If the rank is not within the current node, determine which direction to traverse the tree.
               if (totalToLeft + keyCount <= _rank) {
                   // If the rank is in the right subtree, set the cursor to the right child of the current node.
                   cursor = c.right;
                   // Get the node at the new cursor.
                   c = self.nodes[cursor];
                   uint256 nodeCount = getNodeCount(self, c.left);
                   // Add the number of nodes in the left subtree of the new node to the "totalToLeft" counter.
                   totalToLeft += oldKeyCount + nodeCount;
               } else {
                   // If the rank is in the left subtree, set the cursor to the left child of the current node.
                   cursor = c.left;
                   // Get the node at the new cursor.
                   c = self.nodes[cursor];
                   // We need to update the keyCount here.
                   keyCount = c.keys.length;
                   uint256 nodeCount = getNodeCount(self, c.right);
                   // Subtract the number of nodes in the right subtree of the new node from the "totalToLeft" counter.
                   if (totalToLeft >= (keyCount + nodeCount)) {
                       totalToLeft -= keyCount + nodeCount;
                   } else if (totalToLeft >= keyCount) {
                       totalToLeft -= keyCount;
                   } else {
                       finished = true;
                   }
               }
           }


           // Check if the cursor has moved outside the bounds of the tree.
           if (!exists(self, cursor)) {
               // If so, finish the loop.
               finished = true;
           }
       }
   }


   function insert(Tree storage self, uint256 key, uint value) internal {
       require(value != EMPTY, "OrderStatisticsTree(405) - Value to insert cannot be zero");
       require(
           !keyExists(self, key, value),
           "OrderStatisticsTree(406) - Value and Key pair exists. Cannot be inserted again."
       );
       uint cursor;
       uint probe = self.root;
       while (probe != EMPTY) {
           cursor = probe;
           if (value < probe) {
               probe = self.nodes[probe].left;
           } else if (value > probe) {
               probe = self.nodes[probe].right;
           } else if (value == probe) {
               self.nodes[probe].keys.push(key);
               self.nodes[probe].keyMap[key] = self.nodes[probe].keys.length - uint(1);
               return;
           }
           self.nodes[cursor].count++;
       }
       Node storage nValue = self.nodes[value];
       nValue.parent = cursor;
       nValue.left = EMPTY;
       nValue.right = EMPTY;
       nValue.red = true;
       nValue.keys.push(key);
       nValue.keyMap[key] = nValue.keys.length - uint(1);
       if (cursor == EMPTY) {
           self.root = value;
       } else if (value < cursor) {
           self.nodes[cursor].left = value;
       } else {
           self.nodes[cursor].right = value;
       }
       insertFixup(self, value);
   }


   function remove(Tree storage self, uint256 key, uint value) internal {
       require(value != EMPTY, "OrderStatisticsTree(407) - Value to delete cannot be zero");
       require(keyExists(self, key, value), "OrderStatisticsTree(408) - Value to delete does not exist.");
       Node storage nValue = self.nodes[value];
       uint rowToDelete = nValue.keyMap[key];
       // Put the last element in the place of the row to delete.
       nValue.keys[rowToDelete] = nValue.keys[nValue.keys.length - uint(1)];
       // Set the keyMap for the key THAT WAS JUST MOVED FROM THE END TO THE POSITION that was
       // being deleted.
       // This is important so that the keyMap points to the correct place for that key that was moved.
       nValue.keyMap[nValue.keys[rowToDelete]] = rowToDelete;


       // Then pop the last element.
       nValue.keys.pop();
       uint probe;
       uint cursor;
       if (nValue.keys.length == 0) {
           if (self.nodes[value].left == EMPTY || self.nodes[value].right == EMPTY) {
               cursor = value;
           } else {
               cursor = self.nodes[value].right;
               while (self.nodes[cursor].left != EMPTY) {
                   cursor = self.nodes[cursor].left;
               }
           }
           if (self.nodes[cursor].left != EMPTY) {
               probe = self.nodes[cursor].left;
           } else {
               probe = self.nodes[cursor].right;
           }
           uint cursorParent = self.nodes[cursor].parent;
           self.nodes[probe].parent = cursorParent;
           if (cursorParent != EMPTY) {
               if (cursor == self.nodes[cursorParent].left) {
                   self.nodes[cursorParent].left = probe;
               } else {
                   self.nodes[cursorParent].right = probe;
               }
           } else {
               self.root = probe;
           }
           bool doFixup = !self.nodes[cursor].red;
           if (cursor != value) {
               replaceParent(self, cursor, value);
               self.nodes[cursor].left = self.nodes[value].left;
               self.nodes[self.nodes[cursor].left].parent = cursor;
               self.nodes[cursor].right = self.nodes[value].right;
               self.nodes[self.nodes[cursor].right].parent = cursor;
               self.nodes[cursor].red = self.nodes[value].red;
               (cursor, value) = (value, cursor);
               fixCountRecurse(self, value);
           }
           if (doFixup) {
               removeFixup(self, probe);
           }
           fixCountRecurse(self, cursorParent);
           delete self.nodes[cursor];
       } else {
           fixCountRecurse(self, value);
       }
   }


   function fixCountRecurse(Tree storage self, uint value) private {
       while (value != EMPTY) {
           self.nodes[value].count =
               getNodeCount(self, self.nodes[value].left) +
               getNodeCount(self, self.nodes[value].right);
           value = self.nodes[value].parent;
       }
   }


   function treeMinimum(Tree storage self, uint value) private view returns (uint) {
       while (self.nodes[value].left != EMPTY) {
           value = self.nodes[value].left;
       }
       return value;
   }


   function treeMaximum(Tree storage self, uint value) private view returns (uint) {
       while (self.nodes[value].right != EMPTY) {
           value = self.nodes[value].right;
       }
       return value;
   }


   function rotateLeft(Tree storage self, uint value) private {
       uint cursor = self.nodes[value].right;
       uint parent = self.nodes[value].parent;
       uint cursorLeft = self.nodes[cursor].left;
       self.nodes[value].right = cursorLeft;
       if (cursorLeft != EMPTY) {
           self.nodes[cursorLeft].parent = value;
       }
       self.nodes[cursor].parent = parent;
       if (parent == EMPTY) {
           self.root = cursor;
       } else if (value == self.nodes[parent].left) {
           self.nodes[parent].left = cursor;
       } else {
           self.nodes[parent].right = cursor;
       }
       self.nodes[cursor].left = value;
       self.nodes[value].parent = cursor;
       self.nodes[value].count =
           getNodeCount(self, self.nodes[value].left) +
           getNodeCount(self, self.nodes[value].right);
       self.nodes[cursor].count =
           getNodeCount(self, self.nodes[cursor].left) +
           getNodeCount(self, self.nodes[cursor].right);
   }


   function rotateRight(Tree storage self, uint value) private {
       uint cursor = self.nodes[value].left;
       uint parent = self.nodes[value].parent;
       uint cursorRight = self.nodes[cursor].right;
       self.nodes[value].left = cursorRight;
       if (cursorRight != EMPTY) {
           self.nodes[cursorRight].parent = value;
       }
       self.nodes[cursor].parent = parent;
       if (parent == EMPTY) {
           self.root = cursor;
       } else if (value == self.nodes[parent].right) {
           self.nodes[parent].right = cursor;
       } else {
           self.nodes[parent].left = cursor;
       }
       self.nodes[cursor].right = value;
       self.nodes[value].parent = cursor;
       self.nodes[value].count =
           getNodeCount(self, self.nodes[value].left) +
           getNodeCount(self, self.nodes[value].right);
       self.nodes[cursor].count =
           getNodeCount(self, self.nodes[cursor].left) +
           getNodeCount(self, self.nodes[cursor].right);
   }


   function insertFixup(Tree storage self, uint value) private {
       uint cursor;
       while (value != self.root && self.nodes[self.nodes[value].parent].red) {
           uint valueParent = self.nodes[value].parent;
           if (valueParent == self.nodes[self.nodes[valueParent].parent].left) {
               cursor = self.nodes[self.nodes[valueParent].parent].right;
               if (self.nodes[cursor].red) {
                   self.nodes[valueParent].red = false;
                   self.nodes[cursor].red = false;
                   self.nodes[self.nodes[valueParent].parent].red = true;
                   value = self.nodes[valueParent].parent;
               } else {
                   if (value == self.nodes[valueParent].right) {
                       value = valueParent;
                       rotateLeft(self, value);
                   }
                   valueParent = self.nodes[value].parent;
                   self.nodes[valueParent].red = false;
                   self.nodes[self.nodes[valueParent].parent].red = true;
                   rotateRight(self, self.nodes[valueParent].parent);
               }
           } else {
               cursor = self.nodes[self.nodes[valueParent].parent].left;
               if (self.nodes[cursor].red) {
                   self.nodes[valueParent].red = false;
                   self.nodes[cursor].red = false;
                   self.nodes[self.nodes[valueParent].parent].red = true;
                   value = self.nodes[valueParent].parent;
               } else {
                   if (value == self.nodes[valueParent].left) {
                       value = valueParent;
                       rotateRight(self, value);
                   }
                   valueParent = self.nodes[value].parent;
                   self.nodes[valueParent].red = false;
                   self.nodes[self.nodes[valueParent].parent].red = true;
                   rotateLeft(self, self.nodes[valueParent].parent);
               }
           }
       }
       self.nodes[self.root].red = false;
   }


   function replaceParent(Tree storage self, uint a, uint b) private {
       uint bParent = self.nodes[b].parent;
       self.nodes[a].parent = bParent;
       if (bParent == EMPTY) {
           self.root = a;
       } else {
           if (b == self.nodes[bParent].left) {
               self.nodes[bParent].left = a;
           } else {
               self.nodes[bParent].right = a;
           }
       }
   }


   function removeFixup(Tree storage self, uint value) private {
       uint cursor;
       while (value != self.root && !self.nodes[value].red) {
           uint valueParent = self.nodes[value].parent;
           if (value == self.nodes[valueParent].left) {
               cursor = self.nodes[valueParent].right;
               if (self.nodes[cursor].red) {
                   self.nodes[cursor].red = false;
                   self.nodes[valueParent].red = true;
                   rotateLeft(self, valueParent);
                   cursor = self.nodes[valueParent].right;
               }
               if (!self.nodes[self.nodes[cursor].left].red && !self.nodes[self.nodes[cursor].right].red) {
                   self.nodes[cursor].red = true;
                   value = valueParent;
               } else {
                   if (!self.nodes[self.nodes[cursor].right].red) {
                       self.nodes[self.nodes[cursor].left].red = false;
                       self.nodes[cursor].red = true;
                       rotateRight(self, cursor);
                       cursor = self.nodes[valueParent].right;
                   }
                   self.nodes[cursor].red = self.nodes[valueParent].red;
                   self.nodes[valueParent].red = false;
                   self.nodes[self.nodes[cursor].right].red = false;
                   rotateLeft(self, valueParent);
                   value = self.root;
               }
           } else {
               cursor = self.nodes[valueParent].left;
               if (self.nodes[cursor].red) {
                   self.nodes[cursor].red = false;
                   self.nodes[valueParent].red = true;
                   rotateRight(self, valueParent);
                   cursor = self.nodes[valueParent].left;
               }
               if (!self.nodes[self.nodes[cursor].right].red && !self.nodes[self.nodes[cursor].left].red) {
                   self.nodes[cursor].red = true;
                   value = valueParent;
               } else {
                   if (!self.nodes[self.nodes[cursor].left].red) {
                       self.nodes[self.nodes[cursor].right].red = false;
                       self.nodes[cursor].red = true;
                       rotateLeft(self, cursor);
                       cursor = self.nodes[valueParent].left;
                   }
                   self.nodes[cursor].red = self.nodes[valueParent].red;
                   self.nodes[valueParent].red = false;
                   self.nodes[self.nodes[cursor].left].red = false;
                   rotateRight(self, valueParent);
                   value = self.root;
               }
           }
       }
       self.nodes[value].red = false;
   }
}