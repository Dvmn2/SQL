DROP TABLE IF EXISTS track;
DROP TABLE IF EXISTS album;
DROP TABLE IF EXISTS artist;



-- A
CREATE TABLE artist (
    artist_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         varchar(200) NOT NULL UNIQUE,
    header_url   text,
    description  text
);

-- B
CREATE TABLE album (
    album_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    artist_id     integer NOT NULL
                  REFERENCES artist (artist_id),          -- FK на A
    title         varchar(200) NOT NULL,
    cover_url     text,
    label         varchar(200),
    release_date  date NOT NULL
);

-- C
CREATE TABLE track (
    track_id      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    album_id      integer NOT NULL
                  REFERENCES album (album_id),            -- FK на B
    title         varchar(200) NOT NULL,
    file_url      text NOT NULL,
    lyrics_url    text,
    play_count    bigint   NOT NULL DEFAULT 0 CHECK (play_count >= 0),
    duration_sec  integer  NOT NULL CHECK (duration_sec > 0),
    composer      varchar(200),
    lyricist      varchar(200),
    disc_no       smallint NOT NULL DEFAULT 0
);



-- A
INSERT INTO artist (name, header_url, description) VALUES
 ('Gojira',         'https://download/gojira_cap.png',
  'Taking their name from the original Japanese pronunciation of Godzilla.'),
 ('Ill Nino',       'https://download/Ill_nino_cap.png',
  'ILL NIñO are an American Latin Metal sextet.'),
 ('Dry Kill Logic', 'https://download/dry_kill_logic_cover.png', NULL);

-- B
INSERT INTO album (artist_id, title, cover_url, label, release_date) VALUES
 ((SELECT artist_id FROM artist WHERE name = 'Gojira'),
  'From Mars To Sirius', 'https://download/gojira_from_mars_to_sirius_cover.png',
  'Listenable Records', '2005-09-27'),
 ((SELECT artist_id FROM artist WHERE name = 'Gojira'),
  'Magma', 'https://download/gojira_magma_cover.png',
  'Roadrunner Records', '2016-06-17'),
 ((SELECT artist_id FROM artist WHERE name = 'Ill Nino'),
  'Revolution', 'https://download/ill_nino_revolution_cover.png',
  'The All Blacks B.V.', '2001-09-10'),
 ((SELECT artist_id FROM artist WHERE name = 'Dry Kill Logic'),
  'The Darker Side of Nonsense', 'https://download/dry_kill_logic_the_darker_side_of_nonsense.ogg',
  'The All Blacks B.V.', '2001-06-18');

-- C
INSERT INTO track (album_id, title, file_url, lyrics_url, play_count,
                   duration_sec, composer, lyricist, disc_no) VALUES
 ((SELECT album_id FROM album WHERE title = 'From Mars To Sirius'),
  'Flying Whales', 'https://download/gojira_flying_whales.ogg',
  'https://download/gojira_flying_whales_text.text', 88505769, 464,
  'Gojira', 'Gojira', 0),
 ((SELECT album_id FROM album WHERE title = 'From Mars To Sirius'),
  'From Mars', 'https://download/gojira_from_mars.ogg',
  'https://download/gojira_from_mars_text.text', 7845137, 144,
  'Joseph Duplantier', 'Gojira', 0),
 ((SELECT album_id FROM album WHERE title = 'From Mars To Sirius'),
  'To Sirius', 'https://download/gojira_to_sirius.ogg',
  'https://download/gojira_to_sirius_text.text', 8907709, 337,
  'Gojira', 'Joseph Duplantier', 1),
 ((SELECT album_id FROM album WHERE title = 'Magma'),
  'The Cell', 'https://download/gojira_the_cell.ogg',
  'https://download/gojira_the_cell_text.text', 26873855, 197,
  'Gojira', 'Gojira', 0),
 ((SELECT album_id FROM album WHERE title = 'Revolution'),
  'Revolution', 'https://download/ill_nino_revolution.ogg',
  'https://download/ill_nino_revolution_text.text', 1691554, 210,
  'Cristian Machado', 'Cristian Machado', 0),
 ((SELECT album_id FROM album WHERE title = 'The Darker Side of Nonsense'),
  'Track 13', 'https://download/dry_kill_logic_track_13.ogg',
  'https://download/dry_kill_logic_track_13_text.text', 2063482, 162,
  'Cilff Rigano', 'Cilff Rigano', 0);
