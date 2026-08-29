--
-- PostgreSQL database dump
--

\restrict xp6CA0G2oiMI5qzbbHn4KryQDRy8tAKih9FCzMuZmo7S9QN90nRQrfUMEW8uyLb

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: owned_assets; Type: TABLE DATA; Schema: public; Owner: don
--

INSERT INTO public.owned_assets (id, owner, category, name, value_krw, note, updated_at, kind, as_of, loan_krw, deposit_krw, monthly_krw, acquire_date, acquire_krw, dispose_date, dispose_krw, re_sgg, re_apt, re_area, link_owned_id, link_account_id, acq_p1, acq_p2, acq_p3, acq_p4, dis_p1, dis_p2, dis_p3, dis_p4) OVERRIDING SYSTEM VALUE VALUES (2, '영한', '부동산', '관악산휴먼시아1단지 60㎡', 0, NULL, '2026-08-04 04:40:16.909439+09', '자가', '2026-08-01', 0, 0, 0, '2014-11-25', 300000000, '2024-07-24', 550000000, '관악구', '관악산휴먼시아1단지', 59.99, NULL, NULL, 0, 0, 0, 300000000, 0, 0, 0, 550000000);
INSERT INTO public.owned_assets (id, owner, category, name, value_krw, note, updated_at, kind, as_of, loan_krw, deposit_krw, monthly_krw, acquire_date, acquire_krw, dispose_date, dispose_krw, re_sgg, re_apt, re_area, link_owned_id, link_account_id, acq_p1, acq_p2, acq_p3, acq_p4, dis_p1, dis_p2, dis_p3, dis_p4) OVERRIDING SYSTEM VALUE VALUES (5, '영한', '부동산', '당산푸르지오', 690000000, NULL, '2026-08-04 05:08:34.65724+09', '전세', '2024-12-14', 0, 0, 0, '2024-12-05', 690000000, NULL, 0, '영등포구', '당산푸르지오', 84.98, NULL, NULL, 5000000, 64000000, 0, 621000000, 0, 0, 0, 0);


--
-- Data for Name: snapshots; Type: TABLE DATA; Schema: public; Owner: don
--

INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-27', '숙진', 373036983, 38233704, 0, 411270687);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-27', '영한', 249869413, 16584988, 690000000, 956454401);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-27', '휘동', 22699849, 613930, 0, 23313779);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-09', '숙진', 273148194, 42157581, 0, 315305775);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-09', '영한', 254194997, 19468890, 690000000, 963663887);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-09', 'TOTAL', 527343191, 61626471, 690000000, 1278969662);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-10', '숙진', 271979654, 7379068, 0, 279358722);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-10', '영한', 253658266, 19468613, 690000000, 963126879);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-10', 'TOTAL', 525637920, 26847681, 690000000, 1242485601);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-11', '숙진', 269043532, 7397863, 0, 276441395);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-11', '영한', 252542656, 19468957, 690000000, 962011613);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-11', 'TOTAL', 521586188, 26866820, 690000000, 1238453008);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-12', '숙진', 268668780, 7388022, 0, 276056802);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-12', '영한', 252604378, 19468777, 690000000, 962073155);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-12', 'TOTAL', 521273158, 26856799, 690000000, 1238129957);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-13', '숙진', 273808059, 7397013, 0, 281205072);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-13', '영한', 252747943, 19468941, 690000000, 962216884);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-13', 'TOTAL', 526556002, 26865954, 690000000, 1243421956);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-14', '숙진', 279659462, 7398677, 0, 287058139);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-14', '영한', 254305165, 19468972, 690000000, 963774137);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-14', 'TOTAL', 533964627, 26867649, 690000000, 1250832276);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-15', '숙진', 277476520, 42158993, 0, 319635513);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-15', '영한', 253955461, 19468916, 690000000, 963424377);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-15', 'TOTAL', 531431981, 61627909, 690000000, 1283059890);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-16', '숙진', 276843995, 42150888, 0, 318994883);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-16', '영한', 253612189, 19468768, 690000000, 963080957);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-16', 'TOTAL', 530456184, 61619656, 690000000, 1282075840);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-17', '숙진', 277476520, 42158993, 0, 319635513);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-17', '영한', 253961012, 19468916, 690000000, 963429928);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-17', 'TOTAL', 531437532, 61627909, 690000000, 1283065441);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-18', '숙진', 278609773, 42155917, 0, 320765690);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-18', '영한', 254236569, 19468859, 690000000, 963705428);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-18', 'TOTAL', 532846342, 61624776, 690000000, 1284471118);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-19', '숙진', 269686831, 42151557, 0, 311838388);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-19', '영한', 261052125, 16615999, 690000000, 967668124);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-19', 'TOTAL', 530738956, 58767556, 690000000, 1279506512);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-20', '숙진', 376847607, 38238443, 0, 415086050);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-20', '영한', 253834979, 16587955, 690000000, 960422934);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-20', 'TOTAL', 630682586, 54826398, 690000000, 1375508984);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-04-30', '영한', 10145925, 5237085, 440478889, 455861899);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-04-30', 'TOTAL', 10145925, 5237085, 440478889, 455861899);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-05-31', '영한', 12051077, 3278291, 442674979, 458004347);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-05-31', 'TOTAL', 12051077, 3278291, 442674979, 458004347);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-06-30', '영한', 12688582, 3613968, 444800227, 461102776);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-06-30', 'TOTAL', 12688582, 3613968, 444800227, 461102776);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-06-30', '영한', 33919398, 646604, 470657410, 505223412);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-06-30', 'TOTAL', 34228818, 745980, 470657410, 505632208);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-07-31', '휘동', 333179, 99381, 0, 432560);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-07-31', '영한', 32554132, 664021, 472853500, 506071653);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-07-31', 'TOTAL', 32887311, 763402, 472853500, 506504213);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-08-31', '휘동', 351763, 99815, 0, 451578);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-08-31', '영한', 32373623, 663757, 475049589, 508086969);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-08-31', '숙진', 0, 1, 0, 1);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-08-31', 'TOTAL', 32725385, 763574, 475049589, 508538548);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-09-30', '영한', 34192413, 946085, 477174837, 512313335);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-09-30', '숙진', 0, 1, 0, 1);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-09-30', 'TOTAL', 34192413, 946086, 477174837, 512313336);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-10-31', '휘동', 0, 11000433, 0, 11000433);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-10-31', '영한', 30172986, 5979728, 479370927, 515523641);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-10-31', '숙진', 0, 1, 0, 1);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-10-31', 'TOTAL', 30172986, 16980162, 479370927, 526524075);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-11-30', '휘동', 0, 11000433, 0, 11000433);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-11-30', '영한', 28821892, 6129076, 481496175, 516447143);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-11-30', '숙진', 0, 1, 0, 1);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-11-30', 'TOTAL', 28821892, 17129510, 481496175, 527447577);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-12-31', '휘동', 0, 11000433, 0, 11000433);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-12-31', '영한', 29526462, 6446258, 483692264, 519664984);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-12-31', '숙진', 0, 50001, 0, 50001);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-12-31', 'TOTAL', 29526462, 17496692, 483692264, 530715418);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-01-31', '휘동', 1315377, 9626543, 0, 10941920);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-01-31', '영한', 37861096, 6560528, 485888354, 530309978);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-01-31', '숙진', 0, 50002, 0, 50002);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-01-31', 'TOTAL', 39176474, 16237073, 485888354, 541301900);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-02-28', '휘동', 1245973, 9626543, 0, 10872516);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-02-28', '영한', 35666025, 9316717, 487871918, 532854660);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-02-28', '숙진', 0, 50002, 0, 50002);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-02-28', 'TOTAL', 36911997, 18993262, 487871918, 543777178);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-03-31', '휘동', 1320915, 9626543, 0, 10947458);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-03-31', '영한', 37634567, 6902389, 490068008, 534604964);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-03-31', '숙진', 0, 50002, 0, 50002);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-03-31', 'TOTAL', 38955481, 16578934, 490068008, 545602424);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-04-30', '휘동', 1195635, 9626630, 0, 10822264);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-04-30', '영한', 39928935, 12228432, 492193256, 544350623);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-04-30', '숙진', 0, 5050008, 0, 5050008);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-04-30', 'TOTAL', 41124569, 26905070, 492193256, 560222895);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-05-31', '휘동', 2296822, 8412157, 0, 10708979);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-05-31', '영한', 45091341, 10189302, 494389345, 549669988);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-05-31', '숙진', 1838000, 3158648, 0, 4996648);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-27', 'TOTAL', 645606245, 55432622, 690000000, 1391038867);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-05-31', 'TOTAL', 49226163, 21760107, 494389345, 565375615);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-06-30', '휘동', 2165516, 8412207, 0, 10577724);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-06-30', '영한', 38450748, 14770374, 496514593, 549735715);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-06-30', '숙진', 1752000, 3158648, 0, 4910648);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-06-30', 'TOTAL', 42368264, 26341230, 496514593, 565224087);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-07-31', '휘동', 2464903, 8412224, 0, 10877127);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-07-31', '영한', 43066626, 14923638, 498710683, 556700947);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-07-31', '숙진', 1884000, 3160381, 0, 5044381);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-07-31', 'TOTAL', 47415530, 26496243, 498710683, 572622455);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-08-31', '휘동', 2410189, 8425878, 0, 10836067);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-08-31', '영한', 43613787, 15336030, 500906772, 559856589);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-08-31', '숙진', 3431000, 1690331, 0, 5121331);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-08-31', 'TOTAL', 49454976, 25452239, 500906772, 575813987);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-09-30', '휘동', 2293364, 8426211, 0, 10719575);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-09-30', '영한', 42330750, 3264882, 503032020, 548627652);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-09-30', '숙진', 3052000, 1690331, 0, 4742331);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-09-30', 'TOTAL', 47676113, 13381424, 503032020, 564089558);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-10-31', '휘동', 2370886, 8426179, 0, 10797065);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-10-31', '영한', 43601401, 3171389, 505228110, 552000900);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-10-31', '숙진', 3003000, 1692950, 0, 4695950);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-10-31', 'TOTAL', 48975287, 13290518, 505228110, 567493914);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-11-30', '휘동', 2332863, 8429313, 0, 10762176);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-11-30', '영한', 41874938, 2382734, 507353358, 551611030);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-11-30', '숙진', 3111000, 1692950, 0, 4803950);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-11-30', 'TOTAL', 47318801, 12504997, 507353358, 567177157);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-12-31', '휘동', 2013492, 8428894, 0, 10442387);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-12-31', '영한', 39390974, 2635277, 509549447, 551575698);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-12-31', '숙진', 2788000, 1692950, 0, 4480950);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2022-12-31', 'TOTAL', 44192466, 12757121, 509549447, 566499035);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-01-31', '휘동', 2176947, 8432823, 0, 10609770);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-01-31', '영한', 41402786, 2042162, 511745537, 555190484);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-01-31', '숙진', 3799000, 1177217, 0, 4976217);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-01-31', 'TOTAL', 47378733, 11652201, 511745537, 570776471);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-02-28', '휘동', 2322089, 8433671, 0, 10755760);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-02-28', '영한', 41047036, 3182316, 513729102, 557958454);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-02-28', '숙진', 2946500, 2248042, 0, 5194542);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-02-28', 'TOTAL', 46315625, 13864030, 513729102, 573908756);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-03-31', '휘동', 2496514, 8433458, 0, 10929972);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-03-31', '영한', 38157253, 5782372, 515925191, 559864816);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-03-31', '숙진', 3411000, 1718452, 0, 5129452);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-03-31', 'TOTAL', 44064767, 15934282, 515925191, 575924240);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-04-30', '휘동', 2587905, 8433855, 0, 11021761);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-04-30', '영한', 41466557, 6875029, 518050439, 566392026);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-04-30', '숙진', 4291500, 774724, 0, 5066224);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-04-30', 'TOTAL', 48345963, 16083608, 518050439, 582480010);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-05-31', '휘동', 2759714, 8436877, 0, 11196590);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-05-31', '영한', 36349675, 6241963, 520246529, 562838167);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-05-31', '숙진', 4747900, 488891, 0, 5236791);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-05-31', 'TOTAL', 43857289, 15167730, 520246529, 579271548);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-06-30', '휘동', 2932611, 8436893, 0, 11369504);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-06-30', '영한', 38692888, 5968790, 522371777, 567033456);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-06-30', '숙진', 4148500, 1069317, 0, 5217817);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-06-30', 'TOTAL', 45774000, 15475000, 522371777, 583620777);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-07-31', '휘동', 2941897, 8439628, 0, 11381525);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-07-31', '영한', 4681451, 5844705, 524567866, 535094022);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-07-31', '숙진', 37771652, 367154, 0, 38138806);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-07-31', 'TOTAL', 45395000, 14651487, 524567866, 584614353);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-08-31', '휘동', 3004204, 8440316, 0, 11444520);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-08-31', '영한', 10470621, 10149423, 526763956, 547384000);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-08-31', '숙진', 42287758, 8625166, 0, 50912924);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-08-31', 'TOTAL', 55762583, 27214905, 526763956, 609741444);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-09-30', '휘동', 2897365, 8440658, 0, 11338023);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-09-30', '영한', 2292220, 19495967, 528889204, 550677391);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-09-30', '숙진', 43252012, 11146180, 0, 54398192);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-09-30', 'TOTAL', 48441597, 39082805, 528889204, 616413606);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-10-31', '휘동', 2837984, 8440685, 0, 11278668);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-10-31', '영한', 3065043, 18903930, 531085293, 553054267);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-10-31', '숙진', 47277741, 1974921, 0, 49252662);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-10-31', 'TOTAL', 53180768, 29319535, 531085293, 613585597);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-11-30', '휘동', 3005718, 8443322, 0, 11449040);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-11-30', '영한', 5716266, 16460016, 533210541, 555386823);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-11-30', '숙진', 40902592, 8277714, 0, 49180306);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-11-30', 'TOTAL', 49624576, 33181052, 533210541, 616016169);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-12-31', '휘동', 3139806, 8443138, 0, 11582944);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-12-31', '영한', 6103914, 16439080, 535406631, 557949624);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-12-31', '숙진', 44635242, 3666254, 0, 48301495);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2023-12-31', 'TOTAL', 53878962, 28548471, 535406631, 617834064);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-01-31', '휘동', 3318964, 8463431, 0, 11782395);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-01-31', '영한', 10390256, 10788888, 537602720, 558781863);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-01-31', '숙진', 47260652, 2157036, 0, 49417688);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-01-31', 'TOTAL', 60969872, 21409354, 537602720, 619981947);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-02-29', '휘동', 3512123, 8463584, 0, 11975707);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-02-29', '영한', 3776690, 19607893, 539657127, 563041710);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-02-29', '숙진', 45494688, 7904782, 0, 53399470);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-02-29', 'TOTAL', 52783501, 35976259, 539657127, 628416887);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-03-31', '휘동', 3583987, 1833855, 0, 5417842);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-03-31', '영한', 7003638, 18013959, 541853216, 566870814);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-03-31', '숙진', 53158092, 6196138, 0, 59354229);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-03-31', 'TOTAL', 63745717, 26043952, 541853216, 631642885);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-04-30', '휘동', 3529515, 4857262, 0, 8386776);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-04-30', '영한', 11570297, 67482124, 543978464, 623030885);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-04-30', '숙진', 56282918, 1782745, 0, 58065663);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-04-30', 'TOTAL', 71382729, 74122131, 543978464, 689483324);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-05-31', '휘동', 3720034, 6367637, 0, 10087671);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-05-31', '영한', 11753163, 66784976, 546174554, 624712692);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-05-31', '숙진', 53739214, 2785299, 0, 56524513);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-05-31', 'TOTAL', 69212411, 75937912, 546174554, 691324876);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-06-30', '휘동', 3967864, 6679561, 0, 10647426);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-06-30', '영한', 12890008, 66809727, 548299802, 627999536);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-06-30', '숙진', 52726303, 2081717, 0, 54808019);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-06-30', 'TOTAL', 69584175, 75571005, 548299802, 693454981);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-07-31', '휘동', 4110291, 7953658, 0, 12063949);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-07-31', '영한', 9935795, 70481650, 0, 80417446);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-07-31', '숙진', 52013908, 1737969, 0, 53751878);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-07-31', 'TOTAL', 66059994, 80173278, 0, 146233272);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-08-31', '휘동', 4042270, 8304419, 0, 12346689);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-08-31', '영한', 10585883, 69413218, 0, 79999102);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-08-31', '숙진', 48581777, 1711453, 0, 50293230);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-08-31', 'TOTAL', 63209930, 79429090, 0, 142639021);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-09-30', '휘동', 4073072, 8321357, 0, 12394429);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-09-30', '영한', 10476812, 68729007, 0, 79205820);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-09-30', '숙진', 47427796, 1952904, 0, 49380700);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-09-30', 'TOTAL', 61977681, 79003268, 0, 140980949);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-10-31', '휘동', 4244345, 8344176, 0, 12588522);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-10-31', '영한', 13770250, 22794499, 0, 36564750);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-10-31', '숙진', 24519315, 26492701, 0, 51012016);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-10-31', 'TOTAL', 42533910, 57631377, 0, 100165287);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-11-30', '휘동', 9687114, 3271250, 0, 12958364);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-11-30', '영한', 28476767, 8792581, 0, 37269348);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-11-30', '숙진', 31704287, 133514510, 0, 165218798);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-11-30', 'TOTAL', 69868169, 145578341, 0, 215446510);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-12-31', '휘동', 11801242, 2622989, 0, 14424231);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-12-31', '영한', 32450889, 6522776, 690000000, 728973664);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-12-31', '숙진', 32030823, 130354947, 0, 162385770);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2024-12-31', 'TOTAL', 76282953, 139500712, 690000000, 905783666);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-01-31', '휘동', 13768411, 1615325, 0, 15383736);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-01-31', '영한', 34941497, 5345274, 690000000, 730286771);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-01-31', '숙진', 31601620, 132350091, 0, 163951710);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-01-31', 'TOTAL', 80311528, 139310690, 690000000, 909622218);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-02-28', '휘동', 14674526, 332190, 0, 15006716);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-02-28', '영한', 42526911, 1491114, 690000000, 734018025);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-02-28', '숙진', 67205006, 94893084, 0, 162098089);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-02-28', 'TOTAL', 124406442, 96716388, 690000000, 911122830);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-03-31', '휘동', 14116666, 337008, 0, 14453674);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-03-31', '영한', 42763799, 1565732, 690000000, 734329531);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-03-31', '숙진', 67584591, 94641559, 0, 162226151);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-03-31', 'TOTAL', 124465057, 96544300, 690000000, 911009357);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-04-30', '휘동', 15988872, 326893, 0, 16315765);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-04-30', '영한', 47516948, 9702921, 690000000, 747219869);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-04-30', '숙진', 63150888, 94951303, 0, 158102191);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-04-30', 'TOTAL', 126656708, 104981117, 690000000, 921637824);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-05-31', '휘동', 16992727, 1164488, 0, 18157215);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-05-31', '영한', 47175771, 11728529, 690000000, 748904300);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-05-31', '숙진', 57795166, 99402318, 0, 157197484);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-05-31', 'TOTAL', 121963665, 112295335, 690000000, 924259000);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-06-30', '휘동', 18222100, 1146139, 0, 19368239);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-06-30', '영한', 65364601, 4483140, 690000000, 759847740);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-06-30', '숙진', 164687136, 21009671, 0, 185696808);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-06-30', 'TOTAL', 248273837, 26638950, 690000000, 964912787);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-07-31', '휘동', 21078469, 1701126, 0, 22779594);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-07-31', '영한', 60532373, 12677270, 690000000, 763209643);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-07-31', '숙진', 175297921, 53428346, 0, 228726267);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-07-31', 'TOTAL', 256908763, 67806741, 690000000, 1014715504);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-08-31', '휘동', 17006804, 4773337, 0, 21780142);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-08-31', '영한', 53089303, 20087148, 690000000, 763176451);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-08-31', '숙진', 158319590, 75659503, 0, 233979094);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-08-31', 'TOTAL', 228415697, 100519989, 690000000, 1018935686);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-09-30', '휘동', 19288935, 4822344, 0, 24111279);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-09-30', '영한', 64688409, 16195782, 690000000, 770884191);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-09-30', '숙진', 174508461, 70685889, 0, 245194350);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-09-30', 'TOTAL', 258485805, 91704015, 690000000, 1040189820);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-10-31', '휘동', 25043258, 54288, 0, 25097545);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-10-31', '영한', 84880745, 1061950, 690000000, 775942695);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-10-31', '숙진', 213719475, 5411239, 0, 219130713);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-10-31', 'TOTAL', 323643477, 6527477, 690000000, 1020170954);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-11-30', '휘동', 21926554, 519280, 0, 22445834);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-11-30', '영한', 88589361, 1696252, 690000000, 780285613);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-11-30', '숙진', 225479022, 3856537, 0, 229335559);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-11-30', 'TOTAL', 335994936, 6072070, 690000000, 1032067006);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-12-31', '휘동', 20811677, 511210, 0, 21322887);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-12-31', '영한', 82774576, 6592135, 690000000, 779366711);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-12-31', '숙진', 218658822, 4518054, 0, 223176877);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-01-31', '휘동', 19356155, 514066, 0, 19870221);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-01-31', '영한', 93602013, 71133684, 690000000, 854735698);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-01-31', 'TOTAL', 411958247, 84145875, 690000000, 1186104122);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-28', '숙진', 377349006, 38225328, 0, 415574334);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-28', '영한', 252283169, 16579746, 690000000, 958862915);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-28', '휘동', 23405158, 612261, 0, 24017419);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-28', 'TOTAL', 653037333, 55417335, 690000000, 1398454668);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-29', '숙진', 372565667, 38216862, 0, 410782529);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-29', '영한', 251539893, 16574447, 690000000, 958114340);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-29', '휘동', 23106689, 610575, 0, 23717264);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-07-31', '영한', 16987380, 101212, 446996316, 464084908);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-07-31', 'TOTAL', 16987380, 101212, 446996316, 464084908);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-08-31', '영한', 18262533, 107999, 449192406, 467562937);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-08-31', 'TOTAL', 18262533, 107999, 449192406, 467562937);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-09-30', '영한', 15150999, 2418943, 451317654, 468887596);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-09-30', 'TOTAL', 15150999, 2418943, 451317654, 468887596);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-10-31', '영한', 14030252, 2350978, 453513743, 469894974);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-10-31', 'TOTAL', 14030252, 2350978, 453513743, 469894974);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-11-30', '영한', 15853314, 2323134, 455638991, 473815440);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-11-30', 'TOTAL', 15853314, 2323134, 455638991, 473815440);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-12-31', '영한', 17697240, 2133954, 457835081, 477666275);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2020-12-31', 'TOTAL', 17697240, 2133954, 457835081, 477666275);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-01-31', '영한', 18562629, 2884706, 460031170, 481478505);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-01-31', 'TOTAL', 18562629, 2884706, 460031170, 481478505);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-02-28', '영한', 24455855, 98267, 462014735, 486568857);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-02-28', 'TOTAL', 24455855, 98267, 462014735, 486568857);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-03-31', '휘동', 0, 200000, 0, 200000);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-03-31', '영한', 25259058, 339995, 464210825, 489809878);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-03-31', 'TOTAL', 25259058, 539995, 464210825, 490009878);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-04-30', '휘동', 290955, 98958, 0, 389913);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-04-30', '영한', 30302071, 2236, 466336073, 496640379);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-04-30', 'TOTAL', 30593026, 101194, 466336073, 497030293);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-05-31', '휘동', 275882, 99368, 0, 375249);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-05-31', '영한', 31479372, 385360, 468532162, 500396894);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-21', '휘동', 23074862, 617046, 0, 23691908);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-21', '숙진', 378782944, 38249587, 0, 417032531);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-21', '영한', 252150964, 16594929, 690000000, 958745893);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-21', 'TOTAL', 630933908, 54844516, 690000000, 1375778424);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-22', '숙진', 375933498, 38235513, 0, 414169011);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-22', '영한', 251104079, 16586120, 690000000, 957690199);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-22', '휘동', 23031994, 614290, 0, 23646284);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-22', 'TOTAL', 650069571, 55435923, 690000000, 1395505494);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-23', '숙진', 375628038, 38231750, 0, 413859788);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-23', '영한', 250983295, 16583765, 690000000, 957567060);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-23', '휘동', 22997429, 613541, 0, 23610970);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-23', 'TOTAL', 649608762, 55429056, 690000000, 1395037818);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-24', '숙진', 375923225, 38235386, 0, 414158611);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-24', '영한', 251100017, 16586041, 690000000, 957686058);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-24', '휘동', 23030831, 614265, 0, 23645096);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-24', 'TOTAL', 650054073, 55435692, 690000000, 1395489765);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-25', '숙진', 373326136, 38229525, 0, 411555661);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-25', '영한', 253604953, 16582373, 690000000, 960187326);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-25', '휘동', 22538379, 613097, 0, 23151476);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-25', 'TOTAL', 649469468, 55424995, 690000000, 1394894463);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-29', 'TOTAL', 647212249, 55401884, 690000000, 1392614133);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-05-31', 'TOTAL', 31755254, 484727, 468532162, 500772143);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2021-06-30', '휘동', 309420, 99376, 0, 408796);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2025-12-31', 'TOTAL', 322245076, 11621399, 690000000, 1023866474);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-01-31', '숙진', 299000079, 12498125, 0, 311498204);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-02-28', '휘동', 18967411, 515308, 0, 19482719);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-02-28', '영한', 152936332, 51263580, 690000000, 894199912);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-02-28', '숙진', 296685094, 36117750, 0, 332802844);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-02-28', 'TOTAL', 468588837, 87896638, 690000000, 1246485475);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-03-31', '휘동', 19185016, 545732, 0, 19730748);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-03-31', '영한', 169013431, 40515299, 690000000, 899528730);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-03-31', '숙진', 319038429, 21412804, 0, 340451233);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-03-31', 'TOTAL', 507236876, 62473835, 690000000, 1259710712);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-04-30', '휘동', 23671038, 537593, 0, 24208631);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-04-30', '영한', 235166058, 14869010, 690000000, 940035068);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-04-30', '숙진', 389294309, 45968027, 0, 435262335);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-04-30', 'TOTAL', 648131405, 61374629, 690000000, 1399506034);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-05-31', '휘동', 26961676, 549252, 0, 27510928);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-05-31', '영한', 262947181, 296873, 690000000, 953244054);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-05-31', '숙진', 455820216, 19308318, 0, 475128535);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-05-31', 'TOTAL', 745729074, 20154443, 690000000, 1455883517);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-06-30', '휘동', 28605150, 564079, 0, 29169229);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-06-30', '영한', 274539903, 286960, 690000000, 964826863);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-06-30', '숙진', 481042462, 33264097, 0, 514306559);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-06-30', 'TOTAL', 784187515, 34115136, 690000000, 1508302651);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-07-31', '휘동', 20819943, 626738, 0, 21446681);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-07-31', '영한', 239431756, 19426770, 690000000, 948858525);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-07-31', '숙진', 369800050, 30107862, 0, 399907912);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-07-31', 'TOTAL', 630051749, 50161369, 690000000, 1370213118);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-26', '숙진', 373624360, 38228693, 0, 411853053);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-26', '영한', 253678940, 16581852, 690000000, 960260792);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-26', '휘동', 22474485, 612932, 0, 23087417);
INSERT INTO public.snapshots (as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw) VALUES ('2026-08-26', 'TOTAL', 649777785, 55423477, 690000000, 1395201262);


--
-- Data for Name: symbol_aliases; Type: TABLE DATA; Schema: public; Owner: don
--

INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('코카콜라', 'KO', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('엑슨모빌', 'XOM', 'NYSE', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('애플', 'AAPL', 'NASDAQ', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('마이크로소프트', 'MSFT', 'NASDAQ', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('JP모건체이스', 'JPM', 'NYSE', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('AT&T', 'T', 'NYSE', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('아스트라제네카(ADR)', 'AZN', 'NASDAQ', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('INVESCOQQQTRUSTHKD', 'QQQ', 'NASDAQ', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('금99.99_1kg', 'GOLD_KRW_G', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('엑슨모빌 홀딩스', 'XOM', 'NYSE', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('SPDR GOLD SHARES TRUST', 'GLD', 'NYSE', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('ISHARES 0-3M TREASURY BOND', 'SGOV', 'NASDAQ', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('에스케이하이닉스', '000660', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('INVESCO QQQ TRUST', 'QQQ', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('INVESCO QQQ TRUST UNIT SER 1', 'QQQ', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('버라이존커뮤니케이션스', 'VZ', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('SCHWAB US DIVIDEND EQUITY', 'SCHD', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('한국전력기술', '052690', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('FIRST TRUST CLOUD CO', 'SKYY', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('S&P500코어아이셰어즈ETF', 'IVV', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('리오 틴토 ADR', 'RIO', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('씨제이대한통운', '000120', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('케이티', '030200', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('테슬라', 'TSLA', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('클라우드컴퓨팅퍼스트트러스트ETF', 'SKYY', '', 'USD');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('피아이첨단소재', '178920', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('미래에셋비전기업인수목적4호', '477380', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('하나 1Q 미국S&P500미국채혼합50액티브증권상장지수투자', '0052S0', '', 'KRW');
INSERT INTO public.symbol_aliases (name, ticker, market, currency) VALUES ('현대자동차', '005380', '', 'KRW');


--
-- Data for Name: symbol_display; Type: TABLE DATA; Schema: public; Owner: don
--

INSERT INTO public.symbol_display (skey, display) VALUES ('483650', '달바글로벌');
INSERT INTO public.symbol_display (skey, display) VALUES ('047040', '대우건설');
INSERT INTO public.symbol_display (skey, display) VALUES ('QQQ', 'INVESCO QQQ TRUST');
INSERT INTO public.symbol_display (skey, display) VALUES ('SMR', '뉴스케일 파워');
INSERT INTO public.symbol_display (skey, display) VALUES ('0001A0', '덕양에너젠');
INSERT INTO public.symbol_display (skey, display) VALUES ('GOLD_KRW_G', '금 현물 99.99_1Kg');
INSERT INTO public.symbol_display (skey, display) VALUES ('006340', '대원전선');
INSERT INTO public.symbol_display (skey, display) VALUES ('010170', '대한광통신');
INSERT INTO public.symbol_display (skey, display) VALUES ('403850', '더핑크퐁컴퍼니');
INSERT INTO public.symbol_display (skey, display) VALUES ('RIO', '리오 틴토 ADR');
INSERT INTO public.symbol_display (skey, display) VALUES ('VZ', '버라이존');
INSERT INTO public.symbol_display (skey, display) VALUES ('000120', 'CJ대한통운');
INSERT INTO public.symbol_display (skey, display) VALUES ('030200', 'KT');
INSERT INTO public.symbol_display (skey, display) VALUES ('TSLA', '테슬라');
INSERT INTO public.symbol_display (skey, display) VALUES ('SKYY', 'First Trust Cloud Computing ETF');
INSERT INTO public.symbol_display (skey, display) VALUES ('005387', '현대차2우B');
INSERT INTO public.symbol_display (skey, display) VALUES ('005380', '현대차');


--
-- Data for Name: trade_rules; Type: TABLE DATA; Schema: public; Owner: don
--

INSERT INTO public.trade_rules (id, symbol, name, ma_window, vol_mult, qty, env, active, "position", last_price, band_buy, band_sell, ma, atr, last_eval, created_at, ticks, strategy, grid_step, grid_levels, center, state, timeframe, max_position, order_type, gap_ticks, cash_share, eod_ratio, base_cash, liquidate) OVERRIDING SYSTEM VALUE VALUES (13, '011200', 'HMM', 20, 0.5, 10, 'vts', false, 20, 21000, 20924, 20980, 20952, 55, '2026-08-13 15:29:03', '2026-08-06 06:22:58.519935+09', '[["2026-08-13 15:10:11", 20900.0], ["2026-08-13 15:11:08", 20850.0], ["2026-08-13 15:12:09", 20850.0], ["2026-08-13 15:13:04", 20900.0], ["2026-08-13 15:14:03", 20900.0], ["2026-08-13 15:15:05", 20900.0], ["2026-08-13 15:16:11", 20900.0], ["2026-08-13 15:17:08", 20900.0], ["2026-08-13 15:18:05", 20950.0], ["2026-08-13 15:19:05", 21000.0], ["2026-08-13 15:20:06", 21000.0], ["2026-08-13 15:21:02", 21000.0], ["2026-08-13 15:22:06", 21000.0], ["2026-08-13 15:23:02", 21000.0], ["2026-08-13 15:24:02", 21000.0], ["2026-08-13 15:25:05", 21000.0], ["2026-08-13 15:26:02", 21000.0], ["2026-08-13 15:27:03", 21000.0], ["2026-08-13 15:28:03", 21000.0], ["2026-08-13 15:29:03", 21000.0]]', 'bandgrid', 100, 8, NULL, '{"lots": [{"idx": 0, "qty": 10, "buy": 21550}, {"idx": 1, "qty": 10, "buy": 21400}]}', 'intraday', 80, 'ioc', 2, 0.1, 0, 0, false);
INSERT INTO public.trade_rules (id, symbol, name, ma_window, vol_mult, qty, env, active, "position", last_price, band_buy, band_sell, ma, atr, last_eval, created_at, ticks, strategy, grid_step, grid_levels, center, state, timeframe, max_position, order_type, gap_ticks, cash_share, eod_ratio, base_cash, liquidate) OVERRIDING SYSTEM VALUE VALUES (15, '011200', 'HMM커스텀', 20, 1.5, 1, 'vts', true, 7, 21650, 21400, 21600, NULL, NULL, '2026-08-28 15:29:05', '2026-08-14 09:38:03.00172+09', NULL, 'custom', 100, 8, 21500, '{"lots": [{"qty": 7.0, "buy": 21400}], "done": [], "done_date": "2026-08-28", "orders": [{"no": "0000001903", "org": "00950", "side": "buy", "px": 21300, "qty": 41}, {"no": "0000001911", "org": "00950", "side": "buy", "px": 21200, "qty": 41}, {"no": "0000001918", "org": "00950", "side": "buy", "px": 21100, "qty": 41}, {"no": "0000001925", "org": "00950", "side": "buy", "px": 21000, "qty": 41}, {"no": "0000001962", "org": "00950", "side": "buy", "px": 20900, "qty": 42}, {"no": "0000001996", "org": "00950", "side": "buy", "px": 20800, "qty": 42}, {"no": "0000002005", "org": "00950", "side": "buy", "px": 20700, "qty": 42}, {"no": "0000002037", "org": "00950", "side": "sell", "px": 21700, "qty": 1}, {"no": "0000039562", "org": "00950", "side": "sell", "px": 22300, "qty": 7}], "held": 517.0}', 'intraday', 0, 'market', 2, 0.1, 0, 8790552, false);


--
-- Name: owned_assets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: don
--

SELECT pg_catalog.setval('public.owned_assets_id_seq', 6, true);


--
-- Name: trade_rules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: don
--

SELECT pg_catalog.setval('public.trade_rules_id_seq', 15, true);


--
-- PostgreSQL database dump complete
--

\unrestrict xp6CA0G2oiMI5qzbbHn4KryQDRy8tAKih9FCzMuZmo7S9QN90nRQrfUMEW8uyLb

