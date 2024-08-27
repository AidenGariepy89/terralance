create table if not exists player (
    id integer primary key autoincrement,
    username text not null
);

create table if not exists game (
    id integer primary key autoincrement,
    save_path text not null,
    seed integer not null,
    players integer not null
);

create table if not exists game_player (
    player_id integer not null,
    game_id integer not null,
    foreign key(player_id) references player(id),
    foreign key(game_id) references game(id)
);
