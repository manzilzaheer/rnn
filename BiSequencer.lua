------------------------------------------------------------------------
--[[ BiSequencer ]]--
-- Encapsulates forward, backward and merge modules. 
-- Input is a sequence (a table) of tensors.
-- Output is a sequence (a table) of tensors of the same length.
-- Applies a forward rnn to each element in the sequence in
-- forward order and applies a backward rnn in reverse order.
-- For each step, the outputs of both rnn are merged together using
-- the merge module (defaults to nn.JoinTable(1,1)).
-- The sequences in a batch must have the same size.
-- But the sequence length of each batch can vary.
-- It is implemented by decorating a structure of modules that makes 
-- use of 3 Sequencers for the forward, backward and merge modules.
------------------------------------------------------------------------
local BiSequencer, parent = torch.class('nn.BiSequencer', 'nn.Decorator')

function BiSequencer:__init(forward, backward, merge)
   
   if not torch.isTypeOf(forward, 'nn.Module') then
      error"BiSequencer: expecting nn.Module instance at arg 1"
   end
   self.forwardModule = forward
   
   self.backwardModule = backward
   if not self.backwardModule then
      self.backwardModule = forward:clone()
      self.backwardModule:reset()
   end
   if not torch.isTypeOf(self.backwardModule, 'nn.Module') then
      error"BiSequencer: expecting nn.Module instance at arg 2"
   end
   
   if torch.type(merge) == 'number' then
      self.mergeModule = nn.JoinTable(1, merge)
   elseif merge == nil then
      self.mergeModule = nn.JoinTable(1, 1)
   elseif torch.isTypeOf(merge, 'nn.Module') then
      self.mergeModule = merge
   else
      error"BiSequencer: expecting nn.Module or number instance at arg 3"
   end
   
   self.forwardSequencer = nn.Sequencer(self.forwardModule)
   self.backwardSequencer = nn.Sequencer(self.backwardModule)
   self.mergeSequencer = nn.Sequencer(self.mergeModule)
   
   local backward = nn.Sequential()
   backward:add(nn.ReverseTable()) -- reverse
   backward:add(self.backwardSequencer)
   backward:add(nn.ReverseTable()) -- unreverse
   
   local concat = nn.ConcatTable()
   concat:add(self.forwardSequencer):add(backward)
   
   local brnn = nn.Sequential()
   brnn:add(concat)
   brnn:add(nn.ZipTable())
   brnn:add(self.mergeSequencer)
   
   parent.__init(self, brnn)
end

-- Turn this on to feed long sequences using multiple forwards.
-- Only affects evaluation (self.train = false).
-- Essentially, forget() isn't called on rnn module when remember is on
function BiSequencer:remember(remember)
   self._remember = (remember == nil) and true or false
   self.forwardSequencer:remember(self._remember)
   self.backwardSequencer:remember(self._remember)
   self.mergeSequencer:remember(self._remember)
end

-- You can use this to manually forget.
function BiSequencer:forget()
   self.forwardSequencer:forget()
   self.backwardSequencer:forget()
   self.mergeSequencer:forget()
end
