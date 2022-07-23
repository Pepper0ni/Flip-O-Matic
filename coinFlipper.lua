--Flip-0-Matic, originally Roll-O-Matic by MrStump, edited by Pepper0ni

--Distance the coins are placed from the tool
local selfScale=self.getScale()
radius=1.5*math.max(selfScale.x,selfScale.z)
--How high (relative to the tool) the coins are flipped
height=20

coinsActive={}
watchingCoins=false
coinsFlipped=0
printFlips=true

function onLoad(state)
 createButtons()
 local save=json.parse(state)
 printFlips=save.printFlips
 flipCleanup=save.flipCleanup or"off"
 if save.coins then
  for c=1,#save.coins do coinsActive[c]=getObjectFromGUID(save.coins[c])end
 end
 setUpContextMenu()
end

function tryObjectEnter()
 if self.getData().ContainedObjects then return false end
 return true
end

--Activated by button press,pulls coins and starts process
function numberButtonPressed(num,color)
 if self.getData().ContainedObjects then
  if watchingCoins==false then
   --Delete old coins if they exist
   if #coinsActive>0 then deleteCoins()end
   coinsFlipped=0
   watchingCoins=true
   local bagPos,bagRot=self.getPosition(),self.getRotation()
   for i=1,num do
    --Get Position
    local pos=getRadialPosition(i,num,bagPos,bagRot)
    local rot=self.getRotation()
    if math.random()>0.5 then rot.z=rot.z+180 end
    --Removes objects from bag
    coinsActive[i]=self.takeObject({position=pos,rotation=rot,callback="afterSpawn",callback_owner=self,params={color=color,num=num}})
   end
   activeColor=color
   saveData()
   startLuaCoroutine(self,"watchCoin")
  else
   --Error if you try to flip coins again before the first set finishes
   broadcastToColor("Coins are already being flipped",color,{0.8,0.2,0.2})
  end
 else
  --Error if no coin exists
  broadcastToColor("Please place a Coin in the Flip-o-matic.",color,{0.8,0.2,0.2})
 end
end

function afterSpawn(coin,params)
 coin.setAngularVelocity({math.random()*10+10,0,math.random()*40-20})
 coin.addForce({0,height,0},4)
 coinsFlipped=coinsFlipped+1
end

--Coroutine,watching for all the coins to come to rest.
function watchCoin()
 local startTime=os.time()
 repeat
  local restingCount=0
  for i,coin in ipairs(coinsActive) do
   if not coin or coin.resting==true then
    restingCount=restingCount+1
   end
  end
  coroutine.yield(0)
 until (restingCount==#coinsActive and coinsFlipped==#coinsActive)or os.time()>startTime+5
 watchingCoins=false
 --Prints the results if printFlips is enabled
 if printFlips==true then formatRollResults(activeColor)end
 --Automatically deletes the coin if flipCleanup is 0 or higher
 if flipCleanup==0 then
  deleteCoins()
 elseif tonumber(flipCleanup)then
  Wait.time(deleteCoins,flipCleanup)
 end
 return 1
end

--Used to delete coins from previous flips
function deleteCoins()
 for c=1,#coinsActive do
  if coinsActive[c]!=nil then destroyObject(coinsActive[c])end
 end
 coinsActive={}
 watchingCoins=false
 saveData()
end

--Obtains the number of heads and prints them
function formatRollResults(color)
 local heads=0
 for _,coin in pairs(coinsActive) do
  if coin and coin.getValue()==1 then heads=heads+1 end
 end
 local s=Player[color].steam_name.." Flipped "..tostring(heads).." Heads!"
 broadcastToAll(s,stringColorToRGB(color))
end

--Get a radial position to place item
function getRadialPosition(i,i_max,pos,rot)
 local spokes=360/i_max
 local posX=pos.x+math.sin(math.rad((spokes*i)+rot.y))*radius
 local posY=pos.y+0.25
 local posZ=pos.z+math.cos(math.rad((spokes*i)+rot.y))*radius
 return {x=posX,y=posY,z=posZ}
end

function createButtons()
 --Spawns number buttons and assigns a function trigger for each
 local params={
  function_owner=self,
  height=380,
  width=380,
  scale={0.5,1,0.5}
 }
 for c=1,#butPosList do
  butWrapper(params,butPosList[c],"","Flip "..tostring(c).." Coins","but"..c)
  local func=|_,color|numberButtonPressed(c,color)
  _G["but"..c]=func
 end
 butWrapper(params,{0,0,0.73},"","Delete Coins","deleteCoins")
end

function butWrapper(params,pos,label,tool,func,color)
 params.position=pos
 params.label=label
 params.tooltip=tool
 params.click_function=func
 self.createButton(params)
end

--Data table of positions for number buttons 1-9,in order
butPosList={
 {-0.435,0,0.59},{-0.693,0,0.22},{-0.693,0,-0.22},{-0.435,0,-0.59},
 {0,0,-0.73},{0.435,0,-0.59},{0.693,0,-0.22},{0.693,0,0.22},{0.435,0,0.59}
}

function setUpContextMenu()
 if printFlips then
  self.addContextMenuItem("Quiet flips",||changeSetting("printFlips",false))
 else
  self.addContextMenuItem("Print flips",||changeSetting("printFlips",true))
 end
 if flipCleanup!="off"then
  self.addContextMenuItem("Disable Cleanup",||changeSetting("flipCleanup","off"))
 end
 if flipCleanup!=0 then
  self.addContextMenuItem("Instant Cleanup",||changeSetting("flipCleanup",0))
 end
 if flipCleanup!=3 then
  self.addContextMenuItem("Delayed Cleanup",||changeSetting("flipCleanup",3))
 end
end

function changeSetting(setting,value)
 _G[setting]=value
 self.clearContextMenu()
 setUpContextMenu()
 saveData()
end

function onNumberTyped(color,num)
 numberButtonPressed(num,color)
 return true
end

function saveData()
 local save={printFlips=printFlips,flipCleanup=flipCleanup,coins={}}
 for i,coin in pairs(coinsActive) do save.coins[i]=coinsActive[i].guid end
 self.script_state=json.serialize(save)
end
