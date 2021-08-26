--[[ Copyright (c) 2017 Optera
 * Part of Lighted Electric Poles +
 *
 * See LICENSE.md in the project directory for license information.
--]]

local flib = require('__flib__.data-util')

local light_scale = settings.startup["lepp_light_size_factor"].value
local light_size_limit = settings.startup["lepp_light_max_size"].value
local lep_icons_layer = { { icon = "__LightedPolesPlus__/graphics/icons/lighted.png", icon_size = 32, tint = {r=1, g=1, b=1, a=0.85} } }
local pole_entity_blacklist = {}
for name in string.gmatch(settings.startup["lepp_pole_blacklist"].value, '([^, *]+)') do
  pole_entity_blacklist[name] = true
end

local alternative_technology = "optics"

local pole_names = {} -- dictionary [original pole item name] -> lighted pole entity/item/recipe name
local lightedPoles = {}


-- check if recipe contains entry from Items
function GetItemFromRecipeResult(recipe)
  if recipe.result and pole_names[recipe.result] then
    -- log(tostring(recipe.result).." found in "..tostring(recipe.name)..".result")
    return recipe.result
  end
  if recipe.normal and recipe.normal.result and pole_names[recipe.normal.result] then
    -- log(tostring(recipe.normal.result).." found in "..tostring(recipe.name)..".normal.result")
    return recipe.normal.result
  end
  if recipe.expensive and recipe.expensive.result and pole_names[recipe.expensive.result] then
    -- log(tostring(recipe.expensive.result).." found in "..tostring(recipe.name)..".expensive.result")
    return recipe.expensive.result
  end

  if recipe.results then
    for _, item in pairs(recipe.results) do
      if item.name and ( not item.type or item.type == "item") and pole_names[item.name] then
        -- log(tostring(item.name).." found in "..tostring(recipe.name)..".results")
        return item.name
      end
    end
  end
  if recipe.normal and recipe.normal.results then
    for _, item in pairs(recipe.normal.results) do
      if item.name and ( not item.type or item.type == "item") and pole_names[item.name] then
        -- log(tostring(item.name).." found in "..tostring(recipe.name)..".normal.results")
        return item.name
      end
    end
  end
  if recipe.expensive and recipe.expensive.results then
    for _, item in pairs(recipe.expensive.results) do
      if item.name and ( not item.type or item.type == "item") and pole_names[item.name] then
        -- log(tostring(item.name).." found in "..tostring(recipe.name)..".expensive.results")
        return item.name
      end
    end
  end

  return nil
end


-- look through items for electric-poles should save looking through recipes and entities
for _, item in pairs (data.raw["item"]) do
  -- look through all item.place_result in case item and recipe names don't match entity name
  if item.place_result and data.raw["electric-pole"][item.place_result] and not pole_entity_blacklist[item.place_result] then
    -- log("[LEP+] found pole "..item.place_result.." in item "..item.name)
    local pole = data.raw["electric-pole"][item.place_result]
    -- if (not pole.draw_copper_wires or pole.draw_copper_wires == true) -- exclude poles without copper wire connection
    if pole.draw_copper_wires ~= false -- exclude poles without copper wire connection
    and pole.minable and pole.minable.result and pole.minable.result == item.name then
      pole.fast_replaceable_group = pole.fast_replaceable_group or "electric-pole"

      local newName = "lighted-"..pole.name

      -- log("[LEP+] copying entity "..tostring(pole.name).." to "..tostring(newName))
      local newPole = flib.copy_prototype(pole, newName, true)
      newPole.icons = flib.create_icons(pole, lep_icons_layer) or lep_icons_layer
      newPole.localised_name = {"entity-name.lighted-pole", {"entity-name." .. pole.name}}
      if newPole.next_upgrade then
        newPole.next_upgrade = "lighted-"..newPole.next_upgrade
      end

      -- log("[LEP+] copying item "..tostring(item.name).." to "..tostring(newName))
      pole_names[item.name] = newName --save name for technology lookup
      local newItem = flib.copy_prototype(item, newName, true)
      newItem.icons = flib.create_icons(item, lep_icons_layer) or lep_icons_layer
      newItem.localised_name = newPole.localised_name
      newItem.order = item.order.."-0"
      -- log("group: "..tostring(item.subgroup).." order: "..tostring(item.order) )

      newPole.icons = newPole.icons or newItem.icons -- use item icon for lighted pole in case base pole entity had none


      local hidden_lamp = flib.copy_prototype(data.raw["lamp"]["small-lamp"], newName.."-lamp", true)
      hidden_lamp.icons = newPole.icons
      hidden_lamp.localised_name = newPole.localised_name
      hidden_lamp.minable = nil
      hidden_lamp.next_upgrade = nil
      hidden_lamp.flags = {"not-blueprintable", "not-deconstructable", "placeable-off-grid", "not-on-map"}
      hidden_lamp.selectable_in_game = false
      hidden_lamp.collision_box = {{-0.1, -0.1}, {0.1, 0.1}}
      hidden_lamp.selection_box = {{-0.4, -0.4}, {0.4, 0.4}}
      hidden_lamp.collision_mask = { "resource-layer" }
      hidden_lamp.picture_off =
      {
        filename = "__core__/graphics/empty.png",
        priority = "high",
        width = 1,
        height = 1,
        frame_count = 1,
        axially_symmetrical = false,
        direction_count = 1,
      }
      hidden_lamp.picture_on =
      {
        filename = "__core__/graphics/empty.png",
        priority = "high",
        width = 1,
        height = 1,
        frame_count = 1,
        axially_symmetrical = false,
        direction_count = 1,
      }
      local lamp_count = 1
      local light_size = 40 --small lamp default
      hidden_lamp.light = {intensity = 0.9, size = light_size, color = {r=1.0, g=1.0, b=1.0}}
      hidden_lamp.light_when_colored = {intensity = 1, size = light_size * 0.15, color = {r=1.0, g=1.0, b=1.0}}
      hidden_lamp.energy_usage_per_tick = "5kW"
      if light_scale > 0 then
        light_size = math.floor(math.sqrt(newPole.maximum_wire_distance)*(40/math.sqrt(7.5))*light_scale+0.5)  -- scale to small lamp radius on small poles
        if light_size > light_size_limit then light_size = light_size_limit end
        lamp_count = math.ceil(light_size / 40)
        hidden_lamp.light = {intensity = 0.9, size = light_size, color = {r=1.0, g=1.0, b=1.0}}
        hidden_lamp.light_when_colored = {intensity = 1, size = light_size * 0.15, color = {r=1.0, g=1.0, b=1.0}}
        hidden_lamp.energy_usage_per_tick = light_size * 0.125 .."kW"
      end
      log("[LEP+] Created "..newName.."; light size = "..light_size)

      local newRecipe =
      {
        type = "recipe",
        name = newName,
        enabled = "false",
        ingredients =
        {
          {item.name, 1},
          {"small-lamp", lamp_count}
        },
        result = newName
      }

      -- find original recipe so new recipe can be sorted next to it
      for _, recipe in pairs (data.raw["recipe"]) do
        -- take first recipe
        if recipe.result == item.name then
          if recipe.subgroup then newRecipe.subgroup = recipe.subgroup end
          if recipe.order then newRecipe.order = recipe.order.."-0" end
          break
        end
      end

      -- temporary store generated pole, will be added to data after generation is complete
      table.insert(lightedPoles, newPole)
      table.insert(lightedPoles, newItem)
      table.insert(lightedPoles, hidden_lamp)
      table.insert(lightedPoles, newRecipe)
    end
  end

end
data:extend(lightedPoles)

local recipes_found = {}
-- add to technology
for _, tech in pairs(data.raw["technology"]) do
  if tech.effects then
    for _, effect in pairs(tech.effects) do
      if effect.recipe and data.raw["recipe"][effect.recipe] then
        local base_item = GetItemFromRecipeResult(data.raw["recipe"][effect.recipe])
        if base_item then
          if data.raw["technology"][tech.name].effects then
            log("[LEP+] found original pole "..base_item.." in technology "..tech.name..", inserting "..pole_names[base_item].." into technology "..tech.name)
            table.insert(data.raw["technology"][tech.name].effects, {type="unlock-recipe",recipe=pole_names[base_item]})
          else
            log("[LEP+] found original pole "..base_item.." in technology "..tech.name..", creating new effects table for "..pole_names[base_item].." in technology "..tech.name)
            data.raw["technology"][tech.name].effects = {type="unlock-recipe",recipe=pole_names[base_item]}
          end
          -- multiple techs may unlock the same recipe
          recipes_found[base_item] = recipes_found[base_item] and recipes_found[base_item] + 1 or 1
          -- pole_names[base_item] = nil
        end
      end
    end
  end
end

-- add unassigned recipes to optics
local tech = data.raw.technology[alternative_technology]
if tech then
  for original_pole, lighted_pole in pairs(pole_names) do
    if not recipes_found[original_pole] then
      if tech.effects then
        log("[LEP+] no technology unlock found for "..original_pole..", inserting "..lighted_pole.." into technology "..tech.name)
        table.insert(tech.effects, {type="unlock-recipe", recipe=lighted_pole})
      else
        log("[LEP+] no technology unlock found for "..original_pole..", creating new effects table for "..lighted_pole.." in technology "..tech.name)
        tech.effects = {type="unlock-recipe", recipe=lighted_pole}
      end
    end
  end
else
  error("Technology "..alternative_technology.." not found")
end
