SELECT ar.name AS artist, al.title AS album, al.release_date,
       t.title AS track, t.duration_sec, t.play_count
FROM artist ar
JOIN album  al ON al.artist_id = ar.artist_id
JOIN track  t  ON t.album_id   = al.album_id
ORDER BY ar.name, al.release_date, t.disc_no, t.track_id;