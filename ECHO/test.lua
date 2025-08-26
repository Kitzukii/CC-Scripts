local conf = {
    bot_name = "&bECHO",
    bot_command = "echo",
    chatbox_license = "b86b6ad2-1861-4ee8-a1a3-3d5bc3b404ba",
    permission_list = {
        blocked = { -- cannot access bot
            "ivcr",
            "EmmaKnijn",
            "AlexDevs",
            "jak7b"
        },
        normal = { -- basic stuff, chatting and such

        },
        max = { -- all perms
            "Ktzukii",
            "BomberPlays"
        }
    }
}

local sub_commands


local run = shell.run
local tell = function(user,str) return chatbox.tell(user,str,conf.bot_name) end

run("chatbox register ")

while true do
    local event, user, command, args = os.pullEvent("command")

    if command == conf.bot_command then
        print(user, table.concat(args, " "))
        for _,plr in pairs(conf.permission_list.blocked) do
            if plr == user then 
                tell(user, "You're blocked. Fuck you.")
                return
            end
        end
        if user == "Ktzukii" then
            tell(user, table.concat(args, " "))
        else
            tell(user, "Insuffecient permissions!")
        end
    end
end