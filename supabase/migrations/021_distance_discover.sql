-- Distance-based Discover.
--
-- Profiles get the rough centre of their city (never an exact spot),
-- looked up from geo_cities whenever the city changes. Discover then shows
-- only people within the member's distance, or in the same city when one
-- side's city isn't known.

create table if not exists public.geo_cities (
  name text not null,
  state text not null,
  lat double precision not null,
  lng double precision not null,
  main boolean not null default true  -- false for old/other names
);
create index if not exists geo_cities_name on public.geo_cities (lower(name));
alter table public.geo_cities enable row level security;
drop policy if exists "geo_cities readable" on public.geo_cities;
create policy "geo_cities readable" on public.geo_cities for select using (true);

truncate public.geo_cities;
insert into public.geo_cities (name, state, lat, lng, main) values
  ('Mumbai', 'Maharashtra', 19.076, 72.8777, true),
  ('Bombay', 'Maharashtra', 19.076, 72.8777, false),
  ('Pune', 'Maharashtra', 18.5204, 73.8567, true),
  ('Poona', 'Maharashtra', 18.5204, 73.8567, false),
  ('Nagpur', 'Maharashtra', 21.1458, 79.0882, true),
  ('Thane', 'Maharashtra', 19.2183, 72.9781, true),
  ('Navi Mumbai', 'Maharashtra', 19.033, 73.0297, true),
  ('Nashik', 'Maharashtra', 19.9975, 73.7898, true),
  ('Aurangabad', 'Maharashtra', 19.8762, 75.3433, true),
  ('Chhatrapati Sambhajinagar', 'Maharashtra', 19.8762, 75.3433, false),
  ('Sambhajinagar', 'Maharashtra', 19.8762, 75.3433, false),
  ('Solapur', 'Maharashtra', 17.6599, 75.9064, true),
  ('Kolhapur', 'Maharashtra', 16.705, 74.2433, true),
  ('Amravati', 'Maharashtra', 20.9374, 77.7796, true),
  ('Nanded', 'Maharashtra', 19.1383, 77.321, true),
  ('Sangli', 'Maharashtra', 16.8524, 74.5815, true),
  ('Jalgaon', 'Maharashtra', 21.0077, 75.5626, true),
  ('Akola', 'Maharashtra', 20.7002, 77.0082, true),
  ('Latur', 'Maharashtra', 18.4088, 76.5604, true),
  ('Ahmednagar', 'Maharashtra', 19.0948, 74.748, true),
  ('Ahilyanagar', 'Maharashtra', 19.0948, 74.748, false),
  ('Dhule', 'Maharashtra', 20.9042, 74.7749, true),
  ('Satara', 'Maharashtra', 17.6805, 74.0183, true),
  ('Chandrapur', 'Maharashtra', 19.9615, 79.2961, true),
  ('Parbhani', 'Maharashtra', 19.2608, 76.7748, true),
  ('Jalna', 'Maharashtra', 19.8347, 75.8816, true),
  ('Ratnagiri', 'Maharashtra', 16.9902, 73.312, true),
  ('Beed', 'Maharashtra', 18.9891, 75.756, true),
  ('Wardha', 'Maharashtra', 20.7453, 78.6022, true),
  ('Yavatmal', 'Maharashtra', 20.3888, 78.1204, true),
  ('Osmanabad', 'Maharashtra', 18.186, 76.0419, true),
  ('Dharashiv', 'Maharashtra', 18.186, 76.0419, false),
  ('Lonavala', 'Maharashtra', 18.7546, 73.4062, true),
  ('New Delhi', 'Delhi', 28.6139, 77.209, true),
  ('Delhi', 'Delhi', 28.6139, 77.209, false),
  ('Gurugram', 'Haryana', 28.4595, 77.0266, true),
  ('Gurgaon', 'Haryana', 28.4595, 77.0266, false),
  ('Noida', 'Uttar Pradesh', 28.5355, 77.391, true),
  ('Greater Noida', 'Uttar Pradesh', 28.4744, 77.504, true),
  ('Ghaziabad', 'Uttar Pradesh', 28.6692, 77.4538, true),
  ('Faridabad', 'Haryana', 28.4089, 77.3178, true),
  ('Bengaluru', 'Karnataka', 12.9716, 77.5946, true),
  ('Bangalore', 'Karnataka', 12.9716, 77.5946, false),
  ('Mysuru', 'Karnataka', 12.2958, 76.6394, true),
  ('Mysore', 'Karnataka', 12.2958, 76.6394, false),
  ('Mangaluru', 'Karnataka', 12.9141, 74.856, true),
  ('Mangalore', 'Karnataka', 12.9141, 74.856, false),
  ('Hubballi', 'Karnataka', 15.3647, 75.124, true),
  ('Hubli', 'Karnataka', 15.3647, 75.124, false),
  ('Dharwad', 'Karnataka', 15.3647, 75.124, false),
  ('Belagavi', 'Karnataka', 15.8497, 74.4977, true),
  ('Belgaum', 'Karnataka', 15.8497, 74.4977, false),
  ('Kalaburagi', 'Karnataka', 17.3297, 76.8343, true),
  ('Gulbarga', 'Karnataka', 17.3297, 76.8343, false),
  ('Davanagere', 'Karnataka', 14.4644, 75.9218, true),
  ('Ballari', 'Karnataka', 15.1394, 76.9214, true),
  ('Bellary', 'Karnataka', 15.1394, 76.9214, false),
  ('Shivamogga', 'Karnataka', 13.9299, 75.5681, true),
  ('Shimoga', 'Karnataka', 13.9299, 75.5681, false),
  ('Tumakuru', 'Karnataka', 13.3379, 77.1173, true),
  ('Tumkur', 'Karnataka', 13.3379, 77.1173, false),
  ('Udupi', 'Karnataka', 13.3409, 74.7421, true),
  ('Manipal', 'Karnataka', 13.3409, 74.7421, false),
  ('Chennai', 'Tamil Nadu', 13.0827, 80.2707, true),
  ('Madras', 'Tamil Nadu', 13.0827, 80.2707, false),
  ('Coimbatore', 'Tamil Nadu', 11.0168, 76.9558, true),
  ('Madurai', 'Tamil Nadu', 9.9252, 78.1198, true),
  ('Tiruchirappalli', 'Tamil Nadu', 10.7905, 78.7047, true),
  ('Trichy', 'Tamil Nadu', 10.7905, 78.7047, false),
  ('Salem', 'Tamil Nadu', 11.6643, 78.146, true),
  ('Tirunelveli', 'Tamil Nadu', 8.7139, 77.7567, true),
  ('Tiruppur', 'Tamil Nadu', 11.1085, 77.3411, true),
  ('Vellore', 'Tamil Nadu', 12.9165, 79.1325, true),
  ('Erode', 'Tamil Nadu', 11.341, 77.7172, true),
  ('Thoothukudi', 'Tamil Nadu', 8.7642, 78.1348, true),
  ('Tuticorin', 'Tamil Nadu', 8.7642, 78.1348, false),
  ('Thanjavur', 'Tamil Nadu', 10.787, 79.1378, true),
  ('Tanjore', 'Tamil Nadu', 10.787, 79.1378, false),
  ('Ooty', 'Tamil Nadu', 11.4102, 76.695, true),
  ('Udhagamandalam', 'Tamil Nadu', 11.4102, 76.695, false),
  ('Kanchipuram', 'Tamil Nadu', 12.8342, 79.7036, true),
  ('Hyderabad', 'Telangana', 17.385, 78.4867, true),
  ('Secunderabad', 'Telangana', 17.385, 78.4867, false),
  ('Cyberabad', 'Telangana', 17.385, 78.4867, false),
  ('Warangal', 'Telangana', 17.9689, 79.5941, true),
  ('Karimnagar', 'Telangana', 18.4386, 79.1288, true),
  ('Nizamabad', 'Telangana', 18.6725, 78.094, true),
  ('Khammam', 'Telangana', 17.2473, 80.1514, true),
  ('Visakhapatnam', 'Andhra Pradesh', 17.6868, 83.2185, true),
  ('Vizag', 'Andhra Pradesh', 17.6868, 83.2185, false),
  ('Vijayawada', 'Andhra Pradesh', 16.5062, 80.648, true),
  ('Guntur', 'Andhra Pradesh', 16.3067, 80.4365, true),
  ('Nellore', 'Andhra Pradesh', 14.4426, 79.9865, true),
  ('Tirupati', 'Andhra Pradesh', 13.6288, 79.4192, true),
  ('Kurnool', 'Andhra Pradesh', 15.8281, 78.0373, true),
  ('Kakinada', 'Andhra Pradesh', 16.9891, 82.2475, true),
  ('Rajahmundry', 'Andhra Pradesh', 17.0005, 81.804, true),
  ('Rajamahendravaram', 'Andhra Pradesh', 17.0005, 81.804, false),
  ('Anantapur', 'Andhra Pradesh', 14.6819, 77.6006, true),
  ('Amaravati', 'Andhra Pradesh', 16.5131, 80.5165, true),
  ('Kochi', 'Kerala', 9.9312, 76.2673, true),
  ('Cochin', 'Kerala', 9.9312, 76.2673, false),
  ('Ernakulam', 'Kerala', 9.9312, 76.2673, false),
  ('Thiruvananthapuram', 'Kerala', 8.5241, 76.9366, true),
  ('Trivandrum', 'Kerala', 8.5241, 76.9366, false),
  ('Kozhikode', 'Kerala', 11.2588, 75.7804, true),
  ('Calicut', 'Kerala', 11.2588, 75.7804, false),
  ('Thrissur', 'Kerala', 10.5276, 76.2144, true),
  ('Trichur', 'Kerala', 10.5276, 76.2144, false),
  ('Kollam', 'Kerala', 8.8932, 76.6141, true),
  ('Quilon', 'Kerala', 8.8932, 76.6141, false),
  ('Kannur', 'Kerala', 11.8745, 75.3704, true),
  ('Cannanore', 'Kerala', 11.8745, 75.3704, false),
  ('Alappuzha', 'Kerala', 9.4981, 76.3388, true),
  ('Alleppey', 'Kerala', 9.4981, 76.3388, false),
  ('Palakkad', 'Kerala', 10.7867, 76.6548, true),
  ('Palghat', 'Kerala', 10.7867, 76.6548, false),
  ('Kottayam', 'Kerala', 9.5916, 76.5222, true),
  ('Malappuram', 'Kerala', 11.051, 76.0711, true),
  ('Kolkata', 'West Bengal', 22.5726, 88.3639, true),
  ('Calcutta', 'West Bengal', 22.5726, 88.3639, false),
  ('Howrah', 'West Bengal', 22.5958, 88.2636, true),
  ('Durgapur', 'West Bengal', 23.5204, 87.3119, true),
  ('Asansol', 'West Bengal', 23.6739, 86.9524, true),
  ('Siliguri', 'West Bengal', 26.7271, 88.3953, true),
  ('Darjeeling', 'West Bengal', 27.041, 88.2663, true),
  ('Bhubaneswar', 'Odisha', 20.2961, 85.8245, true),
  ('Cuttack', 'Odisha', 20.4625, 85.883, true),
  ('Rourkela', 'Odisha', 22.2604, 84.8536, true),
  ('Puri', 'Odisha', 19.8135, 85.8312, true),
  ('Sambalpur', 'Odisha', 21.4669, 83.9812, true),
  ('Berhampur', 'Odisha', 19.3149, 84.7941, true),
  ('Brahmapur', 'Odisha', 19.3149, 84.7941, false),
  ('Patna', 'Bihar', 25.5941, 85.1376, true),
  ('Gaya', 'Bihar', 24.7914, 85.0002, true),
  ('Bhagalpur', 'Bihar', 25.2425, 86.9842, true),
  ('Muzaffarpur', 'Bihar', 26.1209, 85.3647, true),
  ('Darbhanga', 'Bihar', 26.1542, 85.8918, true),
  ('Purnia', 'Bihar', 25.7771, 87.4753, true),
  ('Aurangabad', 'Bihar', 24.7521, 84.3742, true),
  ('Ranchi', 'Jharkhand', 23.3441, 85.3096, true),
  ('Jamshedpur', 'Jharkhand', 22.8046, 86.2029, true),
  ('Dhanbad', 'Jharkhand', 23.7957, 86.4304, true),
  ('Bokaro', 'Jharkhand', 23.6693, 86.1511, true),
  ('Hazaribagh', 'Jharkhand', 23.9925, 85.3637, true),
  ('Guwahati', 'Assam', 26.1445, 91.7362, true),
  ('Dibrugarh', 'Assam', 27.4728, 94.912, true),
  ('Silchar', 'Assam', 24.8333, 92.7789, true),
  ('Jorhat', 'Assam', 26.7509, 94.2037, true),
  ('Shillong', 'Meghalaya', 25.5788, 91.8933, true),
  ('Imphal', 'Manipur', 24.817, 93.9368, true),
  ('Agartala', 'Tripura', 23.8315, 91.2868, true),
  ('Aizawl', 'Mizoram', 23.7271, 92.7176, true),
  ('Kohima', 'Nagaland', 25.6751, 94.1086, true),
  ('Dimapur', 'Nagaland', 25.9091, 93.7266, true),
  ('Itanagar', 'Arunachal Pradesh', 27.0844, 93.6053, true),
  ('Gangtok', 'Sikkim', 27.3389, 88.6065, true),
  ('Ahmedabad', 'Gujarat', 23.0225, 72.5714, true),
  ('Surat', 'Gujarat', 21.1702, 72.8311, true),
  ('Vadodara', 'Gujarat', 22.3072, 73.1812, true),
  ('Baroda', 'Gujarat', 22.3072, 73.1812, false),
  ('Rajkot', 'Gujarat', 22.3039, 70.8022, true),
  ('Gandhinagar', 'Gujarat', 23.2156, 72.6369, true),
  ('Bhavnagar', 'Gujarat', 21.7645, 72.1519, true),
  ('Jamnagar', 'Gujarat', 22.4707, 70.0577, true),
  ('Junagadh', 'Gujarat', 21.5222, 70.4579, true),
  ('Anand', 'Gujarat', 22.5645, 72.9289, true),
  ('Bhuj', 'Gujarat', 23.242, 69.6669, true),
  ('Vapi', 'Gujarat', 20.3893, 72.9106, true),
  ('Navsari', 'Gujarat', 20.9467, 72.952, true),
  ('Jaipur', 'Rajasthan', 26.9124, 75.7873, true),
  ('Jodhpur', 'Rajasthan', 26.2389, 73.0243, true),
  ('Udaipur', 'Rajasthan', 24.5854, 73.7125, true),
  ('Kota', 'Rajasthan', 25.2138, 75.8648, true),
  ('Ajmer', 'Rajasthan', 26.4499, 74.6399, true),
  ('Bikaner', 'Rajasthan', 28.0229, 73.3119, true),
  ('Alwar', 'Rajasthan', 27.553, 76.6346, true),
  ('Bhilwara', 'Rajasthan', 25.3463, 74.6364, true),
  ('Sikar', 'Rajasthan', 27.6094, 75.1399, true),
  ('Jaisalmer', 'Rajasthan', 26.9157, 70.9083, true),
  ('Pushkar', 'Rajasthan', 26.4897, 74.5511, true),
  ('Indore', 'Madhya Pradesh', 22.7196, 75.8577, true),
  ('Bhopal', 'Madhya Pradesh', 23.2599, 77.4126, true),
  ('Jabalpur', 'Madhya Pradesh', 23.1815, 79.9864, true),
  ('Gwalior', 'Madhya Pradesh', 26.2183, 78.1828, true),
  ('Ujjain', 'Madhya Pradesh', 23.1765, 75.7885, true),
  ('Sagar', 'Madhya Pradesh', 23.8388, 78.7378, true),
  ('Satna', 'Madhya Pradesh', 24.6005, 80.8322, true),
  ('Rewa', 'Madhya Pradesh', 24.5362, 81.3037, true),
  ('Ratlam', 'Madhya Pradesh', 23.3315, 75.0367, true),
  ('Raipur', 'Chhattisgarh', 21.2514, 81.6296, true),
  ('Bhilai', 'Chhattisgarh', 21.1938, 81.3509, true),
  ('Durg', 'Chhattisgarh', 21.1938, 81.3509, false),
  ('Bilaspur', 'Chhattisgarh', 22.0797, 82.1409, true),
  ('Korba', 'Chhattisgarh', 22.3595, 82.7501, true),
  ('Lucknow', 'Uttar Pradesh', 26.8467, 80.9462, true),
  ('Kanpur', 'Uttar Pradesh', 26.4499, 80.3319, true),
  ('Agra', 'Uttar Pradesh', 27.1767, 78.0081, true),
  ('Varanasi', 'Uttar Pradesh', 25.3176, 82.9739, true),
  ('Banaras', 'Uttar Pradesh', 25.3176, 82.9739, false),
  ('Benares', 'Uttar Pradesh', 25.3176, 82.9739, false),
  ('Kashi', 'Uttar Pradesh', 25.3176, 82.9739, false),
  ('Prayagraj', 'Uttar Pradesh', 25.4358, 81.8463, true),
  ('Allahabad', 'Uttar Pradesh', 25.4358, 81.8463, false),
  ('Meerut', 'Uttar Pradesh', 28.9845, 77.7064, true),
  ('Bareilly', 'Uttar Pradesh', 28.367, 79.4304, true),
  ('Aligarh', 'Uttar Pradesh', 27.8974, 78.088, true),
  ('Moradabad', 'Uttar Pradesh', 28.8386, 78.7733, true),
  ('Gorakhpur', 'Uttar Pradesh', 26.7606, 83.3732, true),
  ('Saharanpur', 'Uttar Pradesh', 29.968, 77.5552, true),
  ('Jhansi', 'Uttar Pradesh', 25.4484, 78.5685, true),
  ('Mathura', 'Uttar Pradesh', 27.4924, 77.6737, true),
  ('Vrindavan', 'Uttar Pradesh', 27.4924, 77.6737, false),
  ('Ayodhya', 'Uttar Pradesh', 26.7922, 82.1998, true),
  ('Faizabad', 'Uttar Pradesh', 26.7922, 82.1998, false),
  ('Dehradun', 'Uttarakhand', 30.3165, 78.0322, true),
  ('Haridwar', 'Uttarakhand', 29.9457, 78.1642, true),
  ('Rishikesh', 'Uttarakhand', 30.0869, 78.2676, true),
  ('Haldwani', 'Uttarakhand', 29.2183, 79.513, true),
  ('Nainital', 'Uttarakhand', 29.3919, 79.4542, true),
  ('Roorkee', 'Uttarakhand', 29.8543, 77.888, true),
  ('Chandigarh', 'Chandigarh', 30.7333, 76.7794, true),
  ('Mohali', 'Punjab', 30.7046, 76.7179, true),
  ('SAS Nagar', 'Punjab', 30.7046, 76.7179, false),
  ('Ludhiana', 'Punjab', 30.901, 75.8573, true),
  ('Amritsar', 'Punjab', 31.634, 74.8723, true),
  ('Jalandhar', 'Punjab', 31.326, 75.5762, true),
  ('Patiala', 'Punjab', 30.3398, 76.3869, true),
  ('Bathinda', 'Punjab', 30.211, 74.9455, true),
  ('Panchkula', 'Haryana', 30.6942, 76.8606, true),
  ('Ambala', 'Haryana', 30.3782, 76.7767, true),
  ('Panipat', 'Haryana', 29.3909, 76.9635, true),
  ('Karnal', 'Haryana', 29.6857, 76.9905, true),
  ('Rohtak', 'Haryana', 28.8955, 76.6066, true),
  ('Hisar', 'Haryana', 29.1492, 75.7217, true),
  ('Sonipat', 'Haryana', 28.9931, 77.0151, true),
  ('Shimla', 'Himachal Pradesh', 31.1048, 77.1734, true),
  ('Manali', 'Himachal Pradesh', 32.2432, 77.1892, true),
  ('Dharamshala', 'Himachal Pradesh', 32.219, 76.3234, true),
  ('McLeod Ganj', 'Himachal Pradesh', 32.219, 76.3234, false),
  ('Solan', 'Himachal Pradesh', 30.9045, 77.0967, true),
  ('Mandi', 'Himachal Pradesh', 31.7084, 76.9318, true),
  ('Srinagar', 'Jammu and Kashmir', 34.0837, 74.7973, true),
  ('Jammu', 'Jammu and Kashmir', 32.7266, 74.857, true),
  ('Leh', 'Ladakh', 34.1526, 77.5771, true),
  ('Panaji', 'Goa', 15.4909, 73.8278, true),
  ('Panjim', 'Goa', 15.4909, 73.8278, false),
  ('Goa', 'Goa', 15.4909, 73.8278, false),
  ('Margao', 'Goa', 15.2832, 73.9862, true),
  ('Madgaon', 'Goa', 15.2832, 73.9862, false),
  ('Vasco da Gama', 'Goa', 15.3982, 73.8113, true),
  ('Mapusa', 'Goa', 15.5937, 73.8142, true),
  ('Puducherry', 'Puducherry', 11.9416, 79.8083, true),
  ('Pondicherry', 'Puducherry', 11.9416, 79.8083, false),
  ('Pondy', 'Puducherry', 11.9416, 79.8083, false),
  ('Port Blair', 'Andaman and Nicobar Islands', 11.6234, 92.7265, true),
  ('Sri Vijaya Puram', 'Andaman and Nicobar Islands', 11.6234, 92.7265, false),
  ('Daman', 'Dadra and Nagar Haveli and Daman and Diu', 20.3974, 72.8328, true),
  ('Silvassa', 'Dadra and Nagar Haveli and Daman and Diu', 20.2766, 73.0169, true),
  ('Kavaratti', 'Lakshadweep', 10.5669, 72.642, true);

alter table public.profiles
  add column if not exists lat double precision,
  add column if not exists lng double precision;

-- "Aurangabad, Maharashtra" -> the centre of that city; a state after the
-- comma picks between cities with the same name.
create or replace function public.city_point(city text, out lat double precision, out lng double precision)
language sql stable set search_path = public as $$
  -- A half-typed name ("Mumb") still finds the city it starts.
  select g.lat, g.lng from public.geo_cities g
   where lower(g.name) = lower(trim(split_part(city, ',', 1)))
      or (length(trim(split_part(city, ',', 1))) >= 3
          and lower(g.name) like lower(trim(split_part(city, ',', 1))) || '%')
   order by (lower(g.name) = lower(trim(split_part(city, ',', 1)))) desc,
            (lower(g.state) = lower(trim(split_part(city, ',', 2)))) desc, g.main desc
   limit 1
$$;

create or replace function public.km_between(lat1 double precision, lng1 double precision,
                                             lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

create or replace function public.locate_profile()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.city is distinct from old.city then
    select p.lat, p.lng into new.lat, new.lng from public.city_point(new.city) p;
  end if;
  return new;
end $$;
drop trigger if exists profiles_locate on public.profiles;
create trigger profiles_locate before insert or update of city on public.profiles
  for each row execute function public.locate_profile();

update public.profiles
   set (lat, lng) = (select c.lat, c.lng from public.city_point(city) c)
 where city <> '';

-- Same as before, plus: only people within max_km of you (or in your city
-- when either location is unknown), with the rounded distance.
drop function if exists public.discover_members(integer);
drop function if exists public.discover_members(integer, integer);
create function public.discover_members(max_results integer default 50, max_km integer default null)
returns table(id uuid, name text, age integer, gender text, city text, job text, bio text,
              looking_for text, interests text[], prompt_label text, prompt_answer text,
              photos text[], verified boolean, height_cm integer, languages text[],
              voice_prompt_label text, voice_path text, voice_seconds integer, distance_km integer)
language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(extract(year from age(p.birthday))::int, 0),
         p.gender, p.city, p.job, p.bio, p.looking_for, p.interests,
         p.prompt_label, p.prompt_answer, p.photos, p.verified,
         p.height_cm, p.languages, p.voice_prompt_label, p.voice_path,
         p.voice_seconds, d.km::int
  from public.profiles p
  join public.profiles me on me.id = auth.uid()
  cross join lateral (select case when p.lat is not null and me.lat is not null
                              then public.km_between(me.lat, me.lng, p.lat, p.lng) end as km) d
  where p.id <> me.id
    and p.onboarded and public.visible_to_me(p)
    and cardinality(p.photos) > 0
    and (max_km is null or trim(me.city) = ''
         or d.km <= max_km
         or (d.km is null and lower(trim(split_part(p.city, ',', 1))) = lower(trim(split_part(me.city, ',', 1)))))
    and not exists (select 1 from public.likes l
                    where l.from_user = me.id and l.to_user = p.id)
    and not exists (select 1 from public.passes s
                    where s.from_user = me.id and s.to_user = p.id)
    and not exists (select 1 from public.matches m
                    where (m.user_a, m.user_b) in ((me.id, p.id), (p.id, me.id)))
    and (me.interested_in in ('', 'Everyone')
         or (me.interested_in = 'Women' and p.gender = 'Woman')
         or (me.interested_in = 'Men' and p.gender = 'Man'))
    and (p.is_bot or p.interested_in in ('', 'Everyone')
         or (p.interested_in = 'Women' and me.gender = 'Woman')
         or (p.interested_in = 'Men' and me.gender = 'Man'))
  order by coalesce(p.boosted_until > now(), false) desc, d.km nulls last, p.updated_at desc
  limit max_results
$$;
revoke all on function public.discover_members(integer, integer) from public, anon;
grant execute on function public.discover_members(integer, integer) to authenticated;
