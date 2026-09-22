--!nonstrict
-- Nonblocking audio adapter. No Loaded waits, TimeLength reads or timing gates.
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local Config=require(game:GetService("ReplicatedStorage").Shared.OpeningAudioConfig)
local Audio={}
function Audio.new()
 local self={sounds={},groups={},destroyed=false}
 local folder=Instance.new("Folder");folder.Name="OpeningAudio";folder.Parent=SoundService;self.folder=folder
 function self:play(key)
  if self.destroyed then return nil end
  local category,name=string.match(key,"^([^.]+)%.(.+)$")
  local id=category and Config[category] and Config[category][name]
  if type(id)~="string" or id=="" then return nil end
  -- Reject malformed values locally, without warning spam or asset requests.
  if string.match(id,"^%d+$") then id="rbxassetid://"..id end
  if not string.match(id,"^rbxassetid://%d+$") then return nil end
  local mix=table.clone(Config.Mix[category] or Config.Mix.Machinery)
  for k,v in Config.Overrides[key] or {} do mix[k]=v end
  if category=="Music" then
   for sound,info in self.sounds do if info.category=="Music" then sound:Destroy();self.sounds[sound]=nil end end
  end
  for sound,info in self.sounds do if info.key==key and sound.Parent and sound.Looped then return sound end end
  local groupName=mix.SoundGroup or category
  local group=self.groups[groupName]
  if not group then
   group=Instance.new("SoundGroup");group.Name="Opening"..groupName;group.Volume=1;group.Parent=folder;self.groups[groupName]=group
  end
  local sound=Instance.new("Sound")
  sound.Name=name;sound.SoundId=id;sound.Volume=math.clamp(mix.Volume or 0.5,0,1);sound.PlaybackSpeed=math.clamp(mix.PlaybackSpeed or 1,0.5,2)
  sound.Looped=mix.Looped==true;sound.SoundGroup=group;sound.Parent=folder
  self.sounds[sound]={key=key,category=category}
  sound.Ended:Once(function() self.sounds[sound]=nil;sound:Destroy() end)
  -- Failed permissions/loading never block this call. The engine may report
  -- an invalid uploaded ID; replace it with an authorized one in the config.
  pcall(function() sound:Play() end)
  if not sound.Looped then Debris:AddItem(sound,category=="Music" and 240 or 20) end
  return sound
 end
 function self:stopSequence()
  for sound,info in self.sounds do
   if info.category~="Music" then sound:Stop();sound:Destroy();self.sounds[sound]=nil end
  end
 end
 function self:destroy()
  if self.destroyed then return end
  self.destroyed=true
  for sound in self.sounds do sound:Stop() end
  table.clear(self.sounds);folder:Destroy()
 end
 return self
end
return Audio
