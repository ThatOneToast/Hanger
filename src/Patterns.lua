local patterns = {}

patterns["ping"] = {
    command = "ping",
    host = "",
    port = "",
    payload = "",

    -- Rcon Properties
    password = "",
    mc_command = "",
}

patterns["shutdown"] = {
    command = "shutdown",
    host = "",
    port = "",
    payload = "",

    -- Rcon Properties
    password = "",
    mc_command = "",
}

patterns["disconnect"] = {
    command = "close_connection",
    host = "",
    port = "",
    payload = "",

    -- Rcon Properties
    password = "",
    mc_command = "",
}

patterns["new_connection"] = {
    command = "new_connection",
    host = "",
    port = "",
    payload = "",

    -- Rcon Properties
    password = "",
    mc_command = "",
}


return patterns
