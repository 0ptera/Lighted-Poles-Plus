--[[ Copyright (c) 2017 Optera
 * Part of Lighted Electric Poles +
 *
 * See LICENSE.md in the project directory for license information.
--]]

local MOD_NAME = "LightedPolesPlus"

-- local logger = require("__OpteraLib__.script.logger")

function EntityBuilt(event)
	local entity = event.created_entity or event.entity

	if entity.valid and entity.type == "electric-pole" and string.find(entity.name, "lighted%-") then
    -- log("placing hidden lamp for "..entity.name.." at "..entity.position.x..","..entity.position.y )
		local lamp = entity.surface.create_entity{name = entity.name.."-lamp", position = entity.position, force = entity.force}
		lamp.destructible = false
    lamp.minable = false
	end
end

script.on_event(defines.events.on_built_entity, EntityBuilt)
script.on_event(defines.events.on_robot_built_entity, EntityBuilt)
script.on_event(defines.events.script_raised_built, EntityBuilt)



function EntityRemoved(event)
	local entity = event.entity

	if entity.valid and entity.type == "electric-pole" and string.find(entity.name, "lighted%-") then
		local lamps = entity.surface.find_entities_filtered {
			name = entity.name.."-lamp",
			position = entity.position,
		}
		for _, lamp in pairs(lamps) do
      -- log("removing hidden lamp of "..entity.name.." at "..entity.position.x..","..entity.position.y )
			lamp.destroy()
		end
	end
end

script.on_event(defines.events.on_pre_player_mined_item, EntityRemoved)
script.on_event(defines.events.on_entity_died, EntityRemoved)
script.on_event(defines.events.on_robot_pre_mined, EntityRemoved)
script.on_event(defines.events.script_raised_destroy, EntityRemoved)

--[[
Event table returned with the event
    player_index = player_index, --The index of the player who moved the entity
    moved_entity = entity, --The entity that was moved
    start_pos = position --The position that the entity was moved from
]]--
function EntityMoved(event)
  -- log(tostring(event.player_index)..", entity: "..tostring(event.moved_entity.name)..", new pos: "..event.moved_entity.position.x..","..event.moved_entity.position.y..", old pos: "..event.start_pos.x..","..event.start_pos.y)
	local entity = event.moved_entity

	if entity and entity.type == "electric-pole" and string.find(entity.name, "lighted%-") then
		local lamps = entity.surface.find_entities_filtered {
			name = entity.name.."-lamp",
			position = event.start_pos,
		}
    for _, lamp in pairs(lamps) do
      lamp.teleport(entity.position)
		end
	end

end

function onLoad()
  --register to PickerExtended
  if remote.interfaces["picker"] and remote.interfaces["picker"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("picker", "dolly_moved_entity_id"), EntityMoved)
  end
  --register to PickerDollies
  if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), EntityMoved)
  end
end
script.on_init(onLoad)
script.on_load(onLoad)


function Initialize(event)
  -- enable researched recipes
  for i, force in pairs(game.forces) do
    for _, tech in pairs(force.technologies) do
      if tech.researched then
        for _, effect in pairs(tech.effects) do
          if effect.type == "unlock-recipe" then
            force.recipes[effect.recipe].enabled = true
          end
        end
      end
    end
  end


  -- take care of orphaned lamps and poles
  -- removing all hidden lamps and placing them at lighted poles should be faster than checking for lamps without poles and poles without lamps
  if event.mod_changes[MOD_NAME] and event.mod_changes[MOD_NAME].old_version then
    game.print("[LEP+] old version: "..event.mod_changes[MOD_NAME].old_version..", resetting all lamps.")
    -- build name lists for lighted poles and lamps
    local prototype_poles = game.get_filtered_entity_prototypes{ {filter="type", type="electric-pole"} }
    local prototype_lamps = game.get_filtered_entity_prototypes{ {filter="type", type="lamp"} }
    local pole_names = {}
    local lamp_names = {"hidden-small-lamp"}
    for name, pole in pairs(prototype_poles) do
      if string.find(pole.name, "lighted%-") and prototype_lamps[pole.name.."-lamp"] then
        table.insert(pole_names, pole.name)
        table.insert(lamp_names, pole.name.."-lamp")
      end
    end

    log("found pole names:"..serpent.block(pole_names))
    log("found lamp names:"..serpent.block(lamp_names))

    -- replace existing lamps
    for _, surface in pairs(game.surfaces) do
      lamps = surface.find_entities_filtered { name = lamp_names }
      for _, lamp in pairs(lamps) do
        lamp.destroy()
      end

      local poles = surface.find_entities_filtered { name = pole_names }
      for _, pole in pairs(poles) do
        local lamp = pole.surface.create_entity{name = pole.name.."-lamp", position = pole.position, force = pole.force}
        if lamp then
          lamp.destructible = false
          lamp.minable = false
        else
          game.print("[LEP+] Error creating lamp for pole "..pole.name)
        end
      end
    end
  end

end
script.on_configuration_changed(Initialize)