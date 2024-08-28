create table if not exists player (
    id integer primary key autoincrement,
    username text not null
);

create table if not exists game (
    id integer primary key autoincrement,
    save_path text not null,
    seed integer not null,
    players integer not null,
    p1 integer not null,
    p2 integer not null,
    p3 integer,
    p4 integer,
    foreign key(p1) references player(id),
    foreign key(p2) references player(id),
    foreign key(p3) references player(id),
    foreign key(p4) references player(id)
);
