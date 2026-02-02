------------------------------------------------------
-- SEARCH
------------------------------------------------------

SELECT 
    a.id, 
    a.title, 
    a.base_price, 
    a.average_rating, 
    a.rating_count,
    img.url AS cover_image
FROM accommodations a
JOIN address addr ON a.address_id = addr.id
LEFT JOIN accommodation_images img ON a.id = img.accommodation_id AND img.display_order = 1
WHERE addr.city = 'Rio de Janeiro' 
  AND addr.state = 'RJ'
  AND a.is_active = TRUE
ORDER BY a.average_rating DESC;

------------------------------------------------------
-- VIEW ACCOMMODATION
------------------------------------------------------

SELECT * FROM vw_accommodations_details 
WHERE id = 1;

------------------------------------------------------
-- INSERT USER
------------------------------------------------------

INSERT INTO users (name, cpf, email, password_hash)
VALUES ('Joaquim', '12345678901', 'joaquim@email.com', 'senha_segura_hash');

------------------------------------------------------
-- CREATE BOOKING
------------------------------------------------------

INSERT INTO bookings (user_id, accommodation_id, check_in, check_out, total_price)
VALUES (1, 1, '2026-02-01 14:00:00', '2026-02-02 11:00:00', 1500.00);

------------------------------------------------------
-- INSERT REVIEW
------------------------------------------------------

INSERT INTO reviews (booking_id, rating, comment)
VALUES (3, 5, 'Excelente estadia! Tudo muito limpo e organizado.');

------------------------------------------------------
-- VIEW ACCOMMODATION AVAILABILITY
------------------------------------------------------

SELECT 
  av.id,
  av.date,
  av.price_modifier,
  av.status
FROM accommodation_availabilities av
WHERE accommodation_id = 1 
  AND status = 'DISPONIVEL';

------------------------------------------------------
-- VIEW HOST ACCOMMODATIONS
------------------------------------------------------

SELECT id, title, average_rating, rating_count, is_active
FROM accommodations
WHERE host_id = 1;

------------------------------------------------------
-- VIEW GROUP'S FAVORITES
------------------------------------------------------

SELECT 
    g.name AS group_name,
    a.title AS accommodation_title,
    a.base_price
FROM group_favorites gf
JOIN groups g ON gf.group_id = g.id
JOIN accommodations a ON gf.accommodation_id = a.id
WHERE g.id = 1;