-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : minimum_data.sql                                                           |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-03-31                                                                 |
-- | - Update Date   : 2025-06-30                                                                 |
-- | - Description   : Script to insert PostgreSQL 'opas' database minimum data.                  |
-- +----------------------------------------------------------------------------------------------+


-- SCHEMA main
    INSERT INTO main.regions (region_id, region_name, region_istat_code, region_note) VALUES ( 2, 'Valle d''Aosta'       , '02', NULL);

    INSERT INTO main.municipalities
        (mu_id, mu_name, mu_istat_code, mu_catasto_code, mu_cap, mu_note)
    VALUES
        (0, 'Sconosciuto', NULL, NULL, NULL, NULL);

    -- VALLE D'AOSTA --
        INSERT INTO main.provinces
            ( province_name, province_istat_code, province_code, province_note )
        VALUES
            ( 'Aosta', '007', 'AO', null);


        INSERT INTO main.region_provinces
            ( region_id, province_id )
        VALUES
            ( 2, 1 ); -- Valle d'Aosta, Aosta

        INSERT INTO main.municipalities
            (mu_name, mu_istat_code, mu_catasto_code, mu_cap, mu_note)
        VALUES
            ('Allein'                 , '001' , 'A205', '11010', null),   -- 1  Allein
            ('Antey-Saint-André'      , '002' , 'A305', '11020', null),   -- 2  Antey-Saint-Andrè
            ('Aosta'                  , '003' , 'A326', '11100', null),   -- 3  Aosta
            ('Arnad'                  , '004' , 'A424', '11020', null),   -- 4  Arnad
            ('Arvier'                 , '005' , 'A452', '11011', null),   -- 5  Arvier
            ('Avise'                  , '006' , 'A521', '11010', null),   -- 6  Avise
            ('Ayas'                   , '007' , 'A094', '11020', null),   -- 7  Ayas
            ('Aymavilles'             , '008' , 'A108', '11010', null),   -- 8  Aymavilles
            ('Bard'                   , '009' , 'A643', '11020', null),   -- 9  Bard
            ('Bionaz'                 , '010' , 'A877', '11010', null),   -- 10  Bionaz
            ('Brissogne'              , '011' , 'B192', '11020', null),   -- 11  Brissogne
            ('Brusson'                , '012' , 'B230', '11022', null),   -- 12  Brusson
            ('Challand-Saint-Anselme' , '013' , 'C593', '11020', null),   -- 13  Challand-Saint-Anselme
            ('Challand-Saint-Victor'  , '014' , 'C594', '11020', null),   -- 14  Challand-Saint-Victor
            ('Chambave'               , '015' , 'C595', '11023', null),   -- 15  Chambave
            ('Chamois'                , '016' , 'B491', '11020', null),   -- 16  Chamois
            ('Champdepraz'            , '017' , 'C596', '11020', null),   -- 17  Champdepraz
            ('Champorcher'            , '018' , 'B540', '11020', null),   -- 18  Champorcher
            ('Charvensod'             , '019' , 'C598', '11020', null),   -- 19  Charvensod
            ('Châtillon'              , '020' , 'C294', '11024', null),   -- 20  Chatillon
            ('Cogne'                  , '021' , 'C821', '11012', null),   -- 21  Cogne
            ('Courmayeur'             , '022' , 'D012', '11013', null),   -- 22  Courmayeur
            ('Donnas'                 , '023' , 'D338', '11020', null),   -- 23  Donnas
            ('Doues'                  , '024' , 'D356', '11010', null),   -- 24  Doues
            ('Emarèse'                , '025' , 'D402', '11020', null),   -- 25  Emarèse
            ('Etroubles'              , '026' , 'D444', '11014', null),   -- 26  Etroubles
            ('Fénis'                  , '027' , 'D537', '11020', null),   -- 27  Fénis
            ('Fontainemore'           , '028' , 'D666', '11020', null),   -- 28  Fontainemore
            ('Gaby'                   , '029' , 'D839', '11020', null),   -- 29  Gaby
            ('Gignod'                 , '030' , 'E029', '11010', null),   -- 30  Gignod
            ('Gressan'                , '031' , 'E165', '11020', null),   -- 31  Gressan
            ('Gressoney-La-Trinité'   , '032' , 'E167', '11020', null),   -- 32  Gressoney-la-Trinitè
            ('Gressoney-Saint-Jean'   , '033' , 'E168', '11025', null),   -- 33  Gressoney-Saint-Jean
            ('Hône'                   , '034' , 'E273', '11020', null),   -- 34  Hone
            ('Introd'                 , '035' , 'E306', '11010', null),   -- 35  Introd
            ('Issime'                 , '036' , 'E369', '11020', null),   -- 36  Issime
            ('Issogne'                , '037' , 'E371', '11020', null),   -- 37  Issogne
            ('Jovençan'               , '038' , 'E391', '11020', null),   -- 38  Jovencan
            ('La Magdeleine'          , '039' , 'A308', '11020', null),   -- 39  La Magdeleine
            ('La Salle '              , '040' , 'E458', '11015', null),   -- 40  La Salle
            ('La Thuile'              , '041' , 'E470', '11016', null),   -- 41  La Thuile
            ('Lillianes'              , '042' , 'E587', '11020', null),   -- 42  Lillianes
            ('Montjovet'              , '043' , 'F367', '11020', null),   -- 43  Montjovet
            ('Morgex'                 , '044' , 'F726', '11017', null),   -- 44  Morgex
            ('Nus'                    , '045' , 'F987', '11020', null),   -- 45  Nus
            ('Ollomont'               , '046' , 'G045', '11010', null),   -- 46  Ollomont
            ('Oyace'                  , '047' , 'G012', '11010', null),   -- 47  Oyace
            ('Perloz'                 , '048' , 'G459', '11020', null),   -- 48  Perloz
            ('Pollein'                , '049' , 'G794', '11020', null),   -- 49  Pollein
            ('Pontboset'              , '050' , 'G545', '11020', null),   -- 50  Pontboset
            ('Pontey'                 , '051' , 'G860', '11024', null),   -- 51  Pontey
            ('Pont-Saint-Martin'      , '052' , 'G854', '11026', null),   -- 52  Pont-Saint-Martin
            ('Pré-Saint-Didier'       , '053' , 'H042', '11010', null),   -- 53  Prè-Saint-Didier
            ('Quart'                  , '054' , 'H110', '11020', null),   -- 54  Quart
            ('Rhêmes-Notre-Dame'      , '055' , 'H262', '11010', null),   -- 55  Rhemes-Notre-Dame
            ('Rhêmes-Saint-Georges'   , '056' , 'H263', '11010', null),   -- 56  Rhemes-Saint-Georges
            ('Roisan          '       , '057' , 'H497', '11010', null),   -- 57  Roisan
            ('Saint-Christophe'       , '058' , 'H669', '11020', null),   -- 58  Saint-Christophe
            ('Saint-Denis'            , '059' , 'H670', '11023', null),   -- 59  Saint-Denis
            ('Saint-Marcel'           , '060' , 'H671', '11020', null),   -- 60  Saint-Marcel
            ('Saint-Nicolas'          , '061' , 'H672', '11010', null),   -- 61  Saint-Nicolas
            ('Saint-Oyen'             , '062' , 'H673', '11014', null),   -- 62  Saint-Oyen
            ('Saint-Pierre'           , '063' , 'H674', '11010', null),   -- 63  Saint-Pierre
            ('Saint-Rhémy-en-Bosses'  , '064' , 'H675', '11010', null),   -- 64  Saint-Rhémy-en-Bosses
            ('Saint-Vincent'          , '065' , 'H676', '11027', null),   -- 65  Saint-Vincent
            ('Sarre'                  , '066' , 'I442', '11010', null),   -- 66  Sarre
            ('Torgnon'                , '067' , 'L217', '11020', null),   -- 67  Torgnon
            ('Valgrisenche'           , '068' , 'L582', '11010', null),   -- 68  Valgrisenche
            ('Valpelline'             , '069' , 'L643', '11010', null),   -- 69  Valpelline
            ('Valsavarenche'          , '070' , 'L647', '11010', null),   -- 70  Valsavarenche
            ('Valtournenche'          , '071' , 'L654', '11028', null),   -- 71  Valtournenche
            ('Verrayes'               , '072' , 'L783', '11020', null),   -- 72  Verrayes
            ('Verrès'                 , '073' , 'C282', '11029', null),   -- 73  Verrès
            ('Villeneuve'             , '074' , 'L981', '11018', null);   -- 74  Villeneuve

        INSERT INTO main.province_municipalities
            (province_id, mu_id )
        VALUES
            ( 1, 1  ),
            ( 1, 2  ),
            ( 1, 3  ),
            ( 1, 4  ),
            ( 1, 5  ),
            ( 1, 6  ),
            ( 1, 7  ),
            ( 1, 8  ),
            ( 1, 9  ),
            ( 1, 10 ),
            ( 1, 11 ),
            ( 1, 12 ),
            ( 1, 13 ),
            ( 1, 14 ),
            ( 1, 15 ),
            ( 1, 16 ),
            ( 1, 17 ),
            ( 1, 18 ),
            ( 1, 19 ),
            ( 1, 20 ),
            ( 1, 21 ),
            ( 1, 22 ),
            ( 1, 23 ),
            ( 1, 24 ),
            ( 1, 25 ),
            ( 1, 26 ),
            ( 1, 27 ),
            ( 1, 28 ),
            ( 1, 29 ),
            ( 1, 30 ),
            ( 1, 31 ),
            ( 1, 32 ),
            ( 1, 33 ),
            ( 1, 34 ),
            ( 1, 35 ),
            ( 1, 36 ),
            ( 1, 37 ),
            ( 1, 38 ),
            ( 1, 39 ),
            ( 1, 40 ),
            ( 1, 41 ),
            ( 1, 42 ),
            ( 1, 43 ),
            ( 1, 44 ),
            ( 1, 45 ),
            ( 1, 46 ),
            ( 1, 47 ),
            ( 1, 48 ),
            ( 1, 49 ),
            ( 1, 50 ),
            ( 1, 51 ),
            ( 1, 52 ),
            ( 1, 53 ),
            ( 1, 54 ),
            ( 1, 55 ),
            ( 1, 56 ),
            ( 1, 57 ),
            ( 1, 58 ),
            ( 1, 59 ),
            ( 1, 60 ),
            ( 1, 61 ),
            ( 1, 62 ),
            ( 1, 63 ),
            ( 1, 64 ),
            ( 1, 65 ),
            ( 1, 66 ),
            ( 1, 67 ),
            ( 1, 68 ),
            ( 1, 69 ),
            ( 1, 70 ),
            ( 1, 71 ),
            ( 1, 72 ),
            ( 1, 73 ),
            ( 1, 74 );
    -- END VALLE D'AOSTA --

-- SCHEMA bobo
    -- ------------------------------------------------------------------------------------------------
    -- GROUPS
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.groups (gr_name, gr_shortname, gr_sys_admin) VALUES ('Shared'   , 'Shared'    , FALSE); -- 1
    INSERT INTO bobo.groups (gr_name, gr_shortname, gr_sys_admin) VALUES ('Guest'    , 'Guest'     , FALSE); -- 2
    INSERT INTO bobo.groups (gr_name, gr_shortname, gr_sys_admin) VALUES ('OpasAdmin', 'OpasAdmin' ,  TRUE); -- 3

    INSERT INTO bobo.groups (gr_id, gr_name, gr_shortname, gr_sys_admin) VALUES (125, 'Ticket Centro'   , 'Ticket Centro'   ,  FALSE);
    INSERT INTO bobo.groups (gr_id, gr_name, gr_shortname, gr_sys_admin) VALUES (126, 'Manutentori CED' , 'Manutentori CED' ,  FALSE);

    -- ------------------------------------------------------------------------------------------------
    -- USERS
    -- ------------------------------------------------------------------------------------------------
    -- TRUNCATE TABLE bobo.users RESTART IDENTITY CASCADE;
    INSERT INTO bobo.users
        (us_name, us_2nd_name, us_surname, us_role, us_email, us_phone, us_mobile, us_pwd)
    VALUES
        ('Utente', NULL, 'OPAS', 'Admin', 'utente.opas@opas.it', NULL, NULL, crypt('Opas', gen_salt('bf')));

    -- ------------------------------------------------------------------------------------------------
    -- RELATION USER - GROUPS
    -- ------------------------------------------------------------------------------------------------
    -- TRUNCATE TABLE bobo.user_groups RESTART IDENTITY;
    INSERT INTO bobo.user_groups
        (us_id, gr_id)
    VALUES
        -- Shared --
        (1, 1),
        -- OpasAdmin --
        (1, 3)
    ON CONFLICT ON CONSTRAINT bobo_user_groups_ukey DO NOTHING;

    -- ------------------------------------------------------------------------------------------------
    -- COMPANIES
    -- ------------------------------------------------------------------------------------------------
    -- TRUNCATE TABLE bobo.companies RESTART IDENTITY CASCADE;
    INSERT INTO bobo.companies
        (comp_name, comp_desc, comp_title, comp_logo, comp_thumb_logo, comp_address, comp_phone, comp_web, comp_email)
    VALUES
        ('Default', 'Ente di default', 'Benvenuto nel portale OPAS', '/bobo-img/default/loghi/default.png', '/bobo-img/default/loghi/thumb_default.png', 'Via di default', NULL, NULL, NULL),
        ('Azienda UNO', 'Descrizione azienda UNO', 'Benvenuto nel portale OPAS', '/bobo-img/default/loghi/default.png', '/bobo-img/default/loghi/thumb_default.png', 'Via di default', NULL, NULL, NULL);

    -- ------------------------------------------------------------------------------------------------
    -- PORTAL
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.portals
        (portal_id, portal_desc, portal_logo, portal_thumb_logo, portal_footer_text, portal_style, portal_basepath, portal_name )
    VALUES
        (0, 'Benvenuto nel portale OPAS', '/bobo-img/logo.png', '/bobo-img/logo-little.png', 'OPen Air System', NULL, NULL, 'OPen Air System');

    INSERT INTO bobo.portal_properties (admin_gr_id, admin_comp_id, portal_id, linked_gr_id, linked_comp_id, region_id, db_schema_names) VALUES (3, 1, 0, ARRAY[1, 2, 3, 125, 126], ARRAY[1,2], NULL, ARRAY['client_test']);

    -- ------------------------------------------------------------------------------------------------
    -- RELATION USER - COMPANY
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.users_metadata
        (us_id, comp_id, portal_id)
    VALUES
        (1, 1, 0);

    -- ------------------------------------------------------------------------------------------------
    -- PAGES AND MENUS
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.pages
        (page_id, page_name, page_href, page_shortcut_icon)
    VALUES
        ( 1, 'Homepage'                , '/'                    , 'fa-regular fa-globe'                             ),
        ( 2, 'Analyser'                , '/str_analyser'        , 'fa-solid fa-chart-mixed'                         ),
        ( 3, 'Visualizer'              , '/str_visualizer'      , 'fa-solid fa-chart-scatter-bubble'                ),
        ( 4, 'Mapper'                  , '/str_mapper'          , 'fa-regular fa-circle-location-arrow'             ),
        ( 5, 'Help'                    , '/help'                , 'fa-solid fa-comments-question-check'             ),
        ( 6, 'FAQ'                     , '/faq'                 , 'fa-regular fa-hands-holding-heart'               ),
        ( 7, 'FAQ tecnica'             , '/faq_tech'            , 'fa-regular fa-hand-holding-medical'              ),
        ( 8, 'Esci'                    , '/logout'              , 'fa-solid fa-cat-space'                           ),
        ( 9, 'Profilo'                 , '/usr_profile'         , 'fa-solid fa-user-robot'                          ),
        (10, 'Admin'                   , '/usr_admin'           , 'fa-solid fa-user-bounty-hunter'                  ),
        (11, 'Impostazioni'            , '/usr_options'         , 'fa-regular fa-user-gear'                         ),
        (12, 'Reports'                 , '/not_reports'         , 'fa-solid fa-cat-space'                           ),
        (13, 'Tasks'                   , '/not_tasks'           , 'fa-solid fa-cat-space'                           ),
        (14, 'Allarmi'                 , '/not_alarms'          , 'fa-solid fa-cat-space'                           ),
        (15, 'Ritardi'                 , '/not_delays'          , 'fa-solid fa-cat-space'                           ),
        (16, 'Demo'                    , '/demo'                , 'fa-solid fa-alicorn'                             ),
        (17, 'Dataview'                , '/str_dataview'        , 'fa-regular fa-map-location-dot'                  ),
        (18, 'Mappa portale'           , '/map'                 , 'fa-solid fa-globe-stand'                         ),
        (19, 'Sopralluoghi'            , '/rep_qa_sopralluoghi' , 'fa-solid fa-starfighter-twin-ion-engine-advanced'),
        (20, 'Tarature'                , '/rep_qa_tarature'     , 'fa-solid fa-wand-magic-sparkles'                 ),
        (21, 'Manutenzioni'            , '/rep_qa_manutenzioni' , 'fa-regular fa-screwdriver-wrench'                ),
        (22, 'Validazione'             , '/dat_validazione'     , 'fa-solid fa-binary-circle-check'                 ),
        (23, 'Automatici'              , '/rep_automatici'      , 'fa-solid fa-magnifying-glass-chart'              ),
        (24, 'Analisi copertura'       , '/stat_ana_copertura'  , 'fa-regular fa-spider-web'                        ),
        (25, 'Parametri'               , '/ang_parametri'       , 'fa-solid fa-wifi'                                ),
        (26, 'Stazioni'                , '/cnf_stazioni'        , 'fa-solid fa-house-chimney-window'                ),
        (27, 'Strumenti'               , '/cnf_strumenti'       , 'fa-regular fa-box-isometric'                     ),
        (28, 'Tarature automatiche'    , '/dat_tarature_aut'    , 'fa-solid fa-diagram-sankey'                      ),
        (29, 'Periferia'               , '/plan_attivita'       , 'fa-solid fa-list-check'                          ),
        (30, 'Calendario'              , '/calendario'          , 'fa-regular fa-calendar-check'                    ),
        (31, 'Grafici OpenAir'         , '/str_openair'         , 'fa-regular fa-solar-system'                      ),
        (32, 'Bombole'                 , '/cnf_bombole'         , 'fa-solid fa-bottle-water'                        ),
        (33, 'Campagne'                , '/cnf_campagne'        , 'fa-regular fa-caravan-simple'                    ),
        (34, 'Dotazioni'               , '/cnf_dotazioni'       , 'fa-solid fa-shovel-snow'                         ),
        (35, 'Diagnostici'             , '/dat_diagnostici'     , 'fa-regular fa-calendar-lines-pen'                ),
        (36, 'Analyser'                , '/str_ava_analyser'    , 'fa-solid fa-compass-drafting'                    ),
        (37, 'Visualizer'              , '/str_ava_visualizer'  , 'fa-solid fa-forklift'                            ),
        (38, 'Media'                   , '/media'               , 'fa-regular fa-photo-film'                        ),
        (39, 'Allarmi'                 , '/dat_allarmi'         , 'fa-solid fa-bell-exclamation'                    ),
        (40, 'Validazione'             , '/str_ava_validazione' , 'fa-solid fa-toolbox'                             ),
        (42, 'Warning strumenti'       , '/dat_warning'         , 'fa-regular fa-sensor-triangle-exclamation'       ),
        (44, 'Telegram'                , '/div_telegram'        , 'fa-brands fa-telegram'                           ),
        (50, 'Dataset E2a'             , '/info_dataset_e2a'    , 'fa-solid fa-border-top-left'                     ),
        (51, 'Dati istantanei'         , '/dat_istantanei'      , 'fa-regular fa-calendar-clock'                    ),
        (52, 'Verbali'                 , '/rep_verbali'         , 'fa-regular fa-file-pen'                          ),
        (53, 'ALIMS'                   , '/rep_alims'           , 'fa-regular fa-file-waveform'                     ),
        (54, 'Indicatori giornalieri'  , '/stat_indicatori'     , 'fa-regular fa-table-pivot'                       ),
        (55, 'Gestione email'          , '/div_email_gest'      , 'fa-solid fa-envelope-open-text'                  ),
        (57, 'Dataset E1a'             , '/info_dataset_e1a'    , 'fa-solid fa-border-bottom-right'                 ),
        (58, 'Strumenti'               , '/ang_strumenti'       , 'fa-solid fa-tower-broadcast'                     ),
        (59, 'Analisi validazione'     , '/stat_ana_validazione', 'fa-regular fa-list-ol'                           ),
        (60, 'Reportistica'            , '/stat_reportistica'   , 'fa-regular fa-calendar-week'                     ),
        (62, 'Info limiti'             , '/stat_info'           , 'fa-regular fa-memo-circle-info'                  ),
        (63, 'Validazione multilivello', '/dat_validaz_finale'  , 'fa-solid fa-shield-check'                        ),
        (64, 'Immagini Horiba'         , '/dat_horiba'          , 'fa-regular fa-diagram-venn'                      ),
        (65, 'Stazioni'                , '/ang_stazioni'        , 'fa-regular fa-house-signal'                      ),
        (67, 'Parametri di stazione'   , '/cnf_parametri'       , 'fa-regular fa-signal-stream'                     ),
        (68, 'Centro'                  , '/plan_centro'         , 'fa-solid fa-list-tree'                           ),
        (69, 'Notifiche'               , '/div_notifiche'       , 'fa-regular fa-message-lines'                     ),
        (70, 'System Admin'            , '/usr_sysadmin'        , 'fa-regular fa-user-astronaut'                    ),
        (71, 'Strumenti'               , '/stnz_strumenti'      , 'fa-regular fa-shelves'                           );

    SELECT setval('bobo.pages_page_id_seq', 71, true);

    -- ------------------------------------------------------------------------------------------------
    -- RELATION GROUP PAGES WITH GRANTS
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.group_pages
        (gr_id, page_id, gp_iud_grants)
    VALUES
        -- PAGINE COMUNI A TUTTI
        (1,  1, '000'), -- Homepage
        (1,  5, '000'), -- Help
        (1,  8, '111'), -- Esci
        (1,  9 ,'111'), -- Profilo
        (1, 18, '111'), -- Mappa portale
        -- GRUPPO OpasAdmin
        (3,  1, '111'),
        (3,  2, '111'),
        (3,  3, '111'),
        (3,  4, '111'),
        (3,  5, '111'),
        (3,  6, '111'),
        (3,  7, '111'),
        (3,  8, '111'),
        (3,  9, '111'),
        (3, 10, '111'),
        (3, 11, '111'),
        (3, 12, '111'),
        (3, 13, '111'),
        (3, 14, '111'),
        (3, 15, '111'),
        (3, 16, '111'),
        (3, 17, '111'),
        (3, 18, '111'),
        (3, 19, '111'),
        (3, 20, '111'),
        (3, 21, '111'),
        (3, 22, '111'),
        (3, 23, '111'),
        (3, 24, '111'),
        (3, 25, '111'),
        (3, 26, '111'),
        (3, 27, '111'),
        (3, 28, '111'),
        (3, 29, '111'),
        (3, 30, '111'),
        (3, 31, '111'),
        (3, 32, '111'),
        (3, 33, '111'),
        (3, 34, '111'),
        (3, 35, '111'),
        (3, 36, '111'),
        (3, 37, '111'),
        (3, 38, '111'),
        (3, 39, '111'),
        (3, 40, '111'),
        (3, 42, '111'),
        (3, 44, '111'),
        (3, 50, '111'),
        (3, 51, '111'),
        (3, 52, '111'),
        (3, 53, '111'),
        (3, 54, '111'),
        (3, 55, '111'),
        (3, 57, '111'),
        (3, 58, '111'),
        (3, 59, '111'),
        (3, 60, '111'),
        (3, 62, '111'),
        (3, 63, '111'),
        (3, 64, '111'),
        (3, 65, '111'),
        (3, 67, '111'),
        (3, 68, '111'),
        (3, 69, '111'),
        (3, 70, '111'),
        (3, 71, '111')

    ON CONFLICT ON CONSTRAINT bobo_group_pages_ukey DO NOTHING;

    -- ------------------------------------------------------------------------------------------------
    -- MENUS
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.menus
        (menu_type, menu_desc)
    VALUES
        ('sidebarnav', 'Menu principale dell''applicazione con icona grigia'  ),
        ('sidebarnav', 'Menu secondario dell''applicazione con icona colorata'),
        ('usernav'   , 'Menu in alto a sinistra relativo all''utente'         ),
        ('notesnav'  , 'Menu in alto a destra per le notifiche'               );

    -- ------------------------------------------------------------------------------------------------
    -- RELATION MENU PAGES
    -- ------------------------------------------------------------------------------------------------
    INSERT INTO bobo.menu_pages
        (mp_id, menu_id, page_id, mp_name, mp_path, mp_order)
    VALUES
        ( 1, 1, NULL, 'Sidebar'                 , 'sidebar1'                           ,   1),
        ( 2, 1,    1, 'Homepage'                , 'sidebar1.homepage'                  ,   2),
        ( 3, 1, NULL, 'Strumenti'               , 'sidebar1.strumenti'                 , 100),
        ( 4, 1,    2, 'Analyser'                , 'sidebar1.strumenti.analyser'        , 101),
        ( 5, 1,    3, 'Visualizer'              , 'sidebar1.strumenti.visualizer'      , 102),
        ( 6, 1,    4, 'Mapper'                  , 'sidebar1.strumenti.mapper'          , 103),
        ( 7, 1,   16, 'Demo'                    , 'sidebar1.demo'                      , 900),
        ( 8, 2, NULL, 'Sidebar2'                , 'sidebar2'                           ,   1),
        ( 9, 2,    5, 'Help'                    , 'sidebar2.help'                      ,   2),
        (10, 2,    6, 'FAQ'                     , 'sidebar2.faq'                       ,   3),
        (11, 2,    7, 'FAQ tecnica'             , 'sidebar2.faq_tech'                  ,   4),
        (12, 2,    8, 'Esci'                    , 'sidebar2.logout'                    ,   5),
        (13, 3, NULL, 'User'                    , 'user'                               ,   1),
        (14, 3,    9, 'Profilo'                 , 'user.profile'                       ,   3),
        (15, 3,   10, 'Admin'                   , 'user.admin'                         ,   4),
        (16, 3,   11, 'Impostazioni'            , 'user.options'                       ,   5),
        (17, 3,    8, 'Esci'                    , 'user.logout'                        ,   6),
        (18, 4, NULL, 'Notifications'           , 'notifications'                      ,   1),
        (19, 4,   12, 'Reports'                 , 'notifications.reports'              ,   2),
        (20, 4,   13, 'Tasks'                   , 'notifications.tasks'                ,   3),
        (21, 4,   14, 'Allarmi'                 , 'notifications.alarms'               ,   4),
        (22, 4,   15, 'Ritardi'                 , 'notifications.delays'               ,   5),
        (23, 1,   17, 'Dataview'                , 'sidebar1.strumenti.dataview'        , 104),
        (24, 3,   18, 'Mappa portale'           , 'user.map'                           ,   5),
        (25, 1, NULL, 'Report'                  , 'sidebar1.report'                    , 300),
        (26, 1,   19, 'Sopralluoghi'            , 'sidebar1.report.qa_sopralluoghi'    , 301),
        (27, 1,   20, 'Tarature'                , 'sidebar1.report.qa_tarature'        , 302),
        (28, 1,   21, 'Manutenzioni'            , 'sidebar1.report.qa_manutenzioni'    , 303),
        (29, 1, NULL, 'Dati'                    , 'sidebar1.dat'                       , 150),
        (30, 1,   22, 'Validazione'             , 'sidebar1.dat.validazione'           , 151),
        (31, 1,   23, 'Automatici'              , 'sidebar1.report.automatici'         , 310),
        (32, 1,   24, 'Analisi copertura'       , 'sidebar1.stat.anacopertura'         , 204),
        (33, 1, NULL, 'Anagrafica rete'         , 'sidebar1.conf'                      , 400),
        (34, 1,   25, 'Parametri '              , 'sidebar1.anagrafica.parametri'      , 451),
        (35, 1,   26, 'Stazioni '               , 'sidebar1.conf.stazioni'             , 401),
        (36, 1,   27, 'Strumenti'               , 'sidebar1.conf.strumenti'            , 403),
        (37, 1,   28, 'Tarature automatiche'    , 'sidebar1.dat.tarature_aut'          , 155),
        (38, 1, NULL, 'Tickets'                 , 'sidebar1.planning'                  , 350),
        (39, 1,   29, 'Periferia'               , 'sidebar1.planning.attivita'         , 351),
        (40, 1,   30, 'Calendario'              , 'sidebar1.calendario'                ,   3),
        (41, 1,   31, 'Grafici OpenAir'         , 'sidebar1.strumenti.openair'         , 105),
        (42, 1,   32, 'Bombole'                 , 'sidebar1.conf.bombole'              , 404),
        (43, 1,   33, 'Campagne'                , 'sidebar1.conf.campagne'             , 405),
        (44, 1,   34, 'Dotazioni'               , 'sidebar1.conf.dotazioni'            , 406),
        (45, 1,   35, 'Diagnostici'             , 'sidebar1.dat.diagnostici'           , 154),
        (46, 1, NULL, 'Avanzate'                , 'sidebar1.avanzate'                  , 175),
        (47, 1,   36, 'Analyser'                , 'sidebar1.avanzate.analyser'         , 176),
        (48, 1,   37, 'Visualizer'              , 'sidebar1.avanzate.visualizer'       , 177),
        (49, 1,   38, 'Media'                   , 'sidebar1.media'                     , 800),
        (50, 1,   39, 'Allarmi'                 , 'sidebar1.dat.allarmi'               , 157),
        (51, 1,   40, 'Validazione'             , 'sidebar1.avanzate.validazione'      , 178),
        (53, 1,   42, 'Warning strumenti'       , 'sidebar1.dat.warning'               , 156),
        (54, 1, NULL, 'Divulgazione'            , 'sidebar1.divulgazione'              , 700),
        (56, 1,   44, 'Telegram'                , 'sidebar1.divulgazione.telegram'     , 702),
        (57, 1, NULL, 'Infoaria'                , 'sidebar1.infoaria'                  , 500),
        (63, 1,   50, 'Dataset E2a'             , 'sidebar1.infoaria.datasete2a'       , 506),
        (64, 1,   51, 'Dati istantanei'         , 'sidebar1.dat.istantanei'            , 153),
        (65, 1,   52, 'Verbali'                 , 'sidebar1.report.verbali'            , 304),
        (66, 1,   53, 'ALIMS'                   , 'sidebar1.report.alims'              , 305),
        (67, 1, NULL, 'Statistiche'             , 'sidebar1.stat'                      , 200),
        (68, 1,   54, 'Indicatori giornalieri'  , 'sidebar1.stat.indicatori'           , 201),
        (69, 1,   55, 'Gestione email'          , 'sidebar1.divulgazione.emailgest'    , 703),
        (71, 1,   57, 'Dataset E1a'             , 'sidebar1.infoaria.datasete1a'       , 507),
        (72, 1, NULL, 'Anagrafica sistema'      , 'sidebar1.anagrafica'                , 450),
        (73, 1,   58, 'Strumenti'               , 'sidebar1.anagrafica.strumenti'      , 452),
        (74, 1,   59, 'Analisi validazione'     , 'sidebar1.stat.anavalidazione'       , 203),
        (75, 1,   60, 'Reportistica'            , 'sidebar1.stat.reportistica'         , 202),
        (77, 1,   62, 'Info limiti'             , 'sidebar1.stat.info'                 , 205),
        (78, 1,   63, 'Validazione multilivello', 'sidebar1.dat.validaz_finale'        , 152),
        (79, 1,   64, 'Immagini Horiba'         , 'sidebar1.dat.horiba'                , 160),
        (80, 1,   65, 'Stazioni'                , 'sidebar1.anagrafica.stazioni'       , 453),
        (82, 1,   67, 'Parametri di stazione'   , 'sidebar1.conf.parametri'            , 402),
        (83, 1,   68, 'Centro'                  , 'sidebar1.planning.centro'           , 352),
        (84, 1,   69, 'Notifiche'               , 'sidebar1.divulgazione.notifiche'    , 704),
        (85, 3,   70, 'System Admin'            , 'user.sysadmin'                      ,   2),
        (86, 1, null, 'Stanziamenti'            , 'sidebar1.stanziamenti'              , 425),
        (87, 1,   71, 'Strumenti'               , 'sidebar1.stanziamenti.strumenti'    , 426);

    SELECT setval('bobo.menu_pages_mp_id_seq', 87, true);

    INSERT INTO bobo.menu_css
        (menu_css_id, mp_id, menu_css_class, menu_css_expanded, menu_css_icon, menu_css_blank, menu_css_beta)
    VALUES
        ( 1,  2, 'waves-effect waves-dark'          , true , 'ti-world'                           , false, false),
        ( 2,  3, 'has-arrow waves-effect waves-dark', false, 'ti-ruler-pencil'                    , false, false),
        ( 3,  4, NULL                               , true , NULL                                 , true , false),
        ( 4,  5, NULL                               , true , NULL                                 , true , false),
        ( 5,  6, NULL                               , true , NULL                                 , false, false),
        (36,  7, 'waves-effect waves-dark'          , NULL , 'ti-brush-alt'                       , false, false),
        (37,  9, 'waves-effect waves-dark'          , false, 'fa-regular fa-circle text-success'  , false, false),
        (38, 10, 'waves-effect waves-dark'          , false, 'fa-regular fa-circle text-success'  , false, false),
        (39, 11, 'waves-effect waves-dark'          , false, 'fa-regular fa-circle text-success'  , false, false),
        (40, 12, 'waves-effect waves-dark'          , false, 'fa-regular fa-power-off text-danger', false, false),
        (81, 85, NULL                               , NULL , 'ti-panel'                           , false, false),
        (41, 14, NULL                               , NULL , 'ti-user'                            , false, false),
        (42, 15, NULL                               , NULL , 'fa-light fa-rocket'                 , false, false),
        (43, 16, NULL                               , NULL , 'ti-settings'                        , false, false),
        (45, 17, 'btn-logout'                       , NULL , 'fa-regular fa-power-off'            , false, false),
        (46, 19, 'btn btn-danger btn-circle'        , NULL , 'fa-regular fa-file-text'            , false, false),
        (47, 20, 'btn btn-success btn-circle'       , NULL , 'ti-calendar'                        , false, false),
        (48, 21, 'btn btn-warning btn-circle'       , NULL , 'fa-regular fa-exclamation-circle'   , false, false),
        (49, 22, 'btn btn-info btn-circle'          , NULL , 'fa-regular fa-clock'                , false, false),
        ( 7, 23, NULL                               , true , NULL                                 , true , false),
        (44, 24, NULL                               , NULL , 'icon-directions'                    , false, false),
        (21, 25, 'has-arrow waves-effect waves-dark', false, 'ti-write'                           , false, false),
        (22, 26, NULL                               , true , NULL                                 , false, false),
        (23, 27, NULL                               , true , NULL                                 , false, false),
        (24, 28, NULL                               , true , NULL                                 , false, false),
        ( 9, 29, 'has-arrow waves-effect waves-dark', false, 'ti-server'                          , false, false),
        (10, 30, NULL                               , true , NULL                                 , true , false),
        (15, 31, NULL                               , true , NULL                                 , false, false),
        (14, 32, NULL                               , true , NULL                                 , false, false),
        (28, 33, 'has-arrow waves-effect waves-dark', false, 'fa-light fa-box-archive'            , false, false),
        (29, 34, NULL                               , true , NULL                                 , false, false),
        (30, 35, NULL                               , true , NULL                                 , false, false),
        (31, 36, NULL                               , true , NULL                                 , false, false),
        (12, 37, NULL                               , true , NULL                                 , false, false),
        (25, 38, 'has-arrow waves-effect waves-dark', false, 'ti-agenda'                          , false, false),
        (26, 39, NULL                               , true , NULL                                 , false, false),
        (79, 83, NULL                               , true , NULL                                 , false, false),
        (27, 40, 'waves-effect waves-dark'          , true , 'ti-blackboard'                      , false, false),
        ( 8, 41, NULL                               , true , NULL                                 , false, false),
        (32, 42, NULL                               , true , NULL                                 , false, false),
        (33, 43, NULL                               , true , NULL                                 , false, false),
        (34, 44, NULL                               , true , NULL                                 , false, false),
        (11, 45, NULL                               , true , NULL                                 , false, false),
        (17, 46, 'has-arrow waves-effect waves-dark', false, 'ti-palette'                         , false, false),
        (18, 47, NULL                               , true , NULL                                 , false, false),
        (19, 48, NULL                               , true , NULL                                 , false, false),
        (13, 50, NULL                               , true , NULL                                 , false, false),
        (20, 51, NULL                               , true , NULL                                 , false, false),
        (16, 53, NULL                               , true , NULL                                 , false, false),
        (50, 54, 'has-arrow waves-effect waves-dark', false, 'icon-bell'                          , false, false),
        (52, 56, NULL                               , true , NULL                                 , false, false),
        (53, 57, 'has-arrow waves-effect waves-dark', false, 'icon-globe-alt'                     , false, false),
        (59, 63, NULL                               , true , NULL                                 , false, false),
        (60, 64, NULL                               , true , NULL                                 , false, false),
        (61, 65, NULL                               , true , NULL                                 , false, false),
        (62, 66, NULL                               , true , NULL                                 , false, false),
        (63, 67, 'has-arrow waves-effect waves-dark', false, 'ti-stats-up'                        , false, false),
        (64, 68, NULL                               , true , NULL                                 , false, false),
        (65, 69, NULL                               , true , NULL                                 , false, false),
        (67, 71, NULL                               , true , NULL                                 , false, false),
        (68, 72, 'has-arrow waves-effect waves-dark', false, 'ti-briefcase'                       , false, false),
        (69, 73, NULL                               , true , NULL                                 , false, false),
        (70, 74, NULL                               , true , NULL                                 , false, false),
        (71, 75, NULL                               , true , NULL                                 , false, false),
        (73, 77, NULL                               , true , NULL                                 , false, false),
        (74, 78, NULL                               , true , NULL                                 , false, false),
        (75, 79, NULL                               , true , NULL                                 , false, false),
        (76, 80, NULL                               , true , NULL                                 , false, false),
        (78, 82, NULL                               , true , NULL                                 , false, false),
        (80, 84, NULL                               , true , NULL                                 , false, false),
        (82, 86, 'has-arrow waves-effect waves-dark', false, 'fa-light fa-cart-flatbed-boxes'     , false, false),
        (83, 87, NULL                               , false, NULL                                 , false, false);

    SELECT setval('bobo.menu_css_menu_css_id_seq', 83, true);

    -- ----------------------------------------------------------------------------------------------
    -- FAQ
    -- ----------------------------------------------------------------------------------------------
    INSERT INTO bobo.faq_pages
        (faq_page_name)
    VALUES
        ('Info principali' ); -- 1

    INSERT INTO bobo.faq_arguments
        (faq_page_id, faq_arg_title, faq_arg_desc)
    VALUES
        (1, 'Guida all''utilizzo delle FAQ' , 'FAQ sta per Frequently Asked Questions, ovvero le domande ricorrenti degli utenti. Qui trovi una lista delle domande con le risposte più frequenti che vengono fornite ai nuovi arrivati.');
    UPDATE bobo.faq_arguments SET faq_arg_desc_fts = to_tsvector('italian', faq_arg_desc);

-- SCHEMA bobo_tools
    INSERT INTO bobo_tools.general_options
        (go_tool, go_obj)
    VALUES
        (
            'analyser',
            '{
                "boost_series" : 11,
                "boost_data": 8785
            }'::jsonb
        ),
        (
            'visualizer',
            '{
                "boost_series" : 5,
                "boost_data": 8785
            }'::jsonb
        ),
        (
            'dataview',
            '{
                "desc":"Dati osservati di qualità dell''aria",
                "footer":"Open Air System",
                "big_logo":"/bobo-img/dataview/logo-opas.png",
                "link_url":null,
                "link_name":null,
                "main_site":"",
                "chart_logo":"/bobo-img/opas/loghi/logo-little.png",
                "chart_label":"OPAS",
                "little_logo":"/bobo-img/dataview/logo-opas-long.png",
                "main_site_name":""
            }'::jsonb
        ),
        (
            'sysadmin',
            '{ "maintenance": 0 }'::jsonb
        );

    INSERT INTO bobo_tools.homepage_widgets
        (wdg_id, wdg_name, wdg_description, wdg_image_url, wdg_page_html)
    VALUES
        (DEFAULT, 'Aggiornamento dati stazioni'     , 'Tabella riportante lo stato delle stazioni', 'bobo-img/widget-ps/ritardi.png', '/ritardi');

    INSERT INTO bobo.group_widgets
        ( gw_id, gr_id, wdg_id  )
    VALUES
        (DEFAULT, 3,  1 );

-- SCHEMA metadata
    INSERT INTO metadata.measures_cadence
        (measure_cadence_id, measure_cadence_desc, measure_cadence_min, measure_cadence_db)
    VALUES
        (5, 'Cadenza UNO', 1, '1 hour'::interval);

    INSERT INTO metadata.app_aggregations
        (app_agg_id, measure_cadence_id, app_agg_label, app_agg_default)
    VALUES
        (DEFAULT, 5, 'hh'::metadata.e_aggregations, true);

    INSERT INTO metadata.measures_type
        (measure_type_id, measure_type_desc)
    VALUES
        (DEFAULT, 'Misura UNO');

    INSERT INTO metadata.parameters_type
        (pm_type_id, pm_type_desc)
    VALUES
        (1, 'Tipologia UNO');

    INSERT INTO metadata.parameters_unit
        (pm_unit_id, pm_unit_desc)
    VALUES
        (0, '--');

    INSERT INTO metadata.parameters
        (param_id, param_name, param_unit, param_unit_conv, param_decimals)
    VALUES
        (0, 'Param. generico', '--', '--', 0);


    INSERT INTO metadata.parameters_info
        (param_id, pm_info_shortname, pm_info_type_fk)
    VALUES
        (0, 'Generico', 1);

    INSERT INTO metadata.parameters_conversions
        (param_id, pc_conv, pc_from_fulldate, pc_to_fulldate)
    VALUES
        (0, 1, '-infinity', 'infinity');

    INSERT INTO metadata.stations_roaming_type
        (st_roaming_id, st_roaming_desc, st_roaming_info)
    VALUES
        (1, 'Tipologia UNO', 'Descrizione ...');

    INSERT INTO metadata.stations_typology
        (st_typology_id, st_typology_desc, st_typology_info)
    VALUES
        (2, 'Tipologia UNO', 'Descrizione ...');

    INSERT INTO metadata.stations_network_type
        (st_network_id, st_network_desc, st_network_logo, st_network_name, st_network_basepath)
    VALUES
        (DEFAULT, 'Rete UNO', '/bobo-img/logo.png', 'Rete UNO', 'media/rete1');

    INSERT INTO bobo.group_networks
        (gr_id, st_network_id, gn_iud_grants)
    VALUES
        (3,  1, '111')
    ON CONFLICT ON CONSTRAINT bobo_group_networks_ukey DO NOTHING;

    INSERT INTO metadata.periphery_validation_codes
        (pvc_id, pvc_code_id, pvc_code_desc, pvc_code_default, pvc_code_valid)
    VALUES
        (DEFAULT, 0, 'Valido per default', TRUE, TRUE);

    INSERT INTO metadata.auto_validation_codes
        (avc_id, avc_code_id, avc_code_desc, avc_code_default, avc_code_valid)
    VALUES
        (DEFAULT, 0, 'Valido per default', TRUE, TRUE);

    INSERT INTO metadata.user_validation_codes
        (uvc_id, uvc_code_id, uvc_code_desc, uvc_code_default, uvc_code_valid)
    VALUES
        (DEFAULT, 0, 'Valido', TRUE, TRUE);

    INSERT INTO metadata.final_validation_codes
        (fvc_id, fvc_code_id, fvc_code_desc, fvc_code_default, fvc_code_valid)
    VALUES
        (DEFAULT, 0, 'Non validato', TRUE, FALSE);

-- SCHEMA equipments
    INSERT INTO equipments.brands
        (brand_id, brand_name)
    VALUES
        (0, '');

    INSERT INTO equipments.models
        (model_id, model_name)
    VALUES
        (0, 'Strumento generico');

    INSERT INTO equipments.constructors
        (constr_id, constr_name)
    VALUES
        (0, '');

    INSERT INTO equipments.categories
        (category_id, category_name, category_short_name)
    VALUES
        (0, 'Da definire'  , NULL),
        (1, 'Categoria UNO', 'UNO');

    INSERT INTO equipments.instruments_type
        (instr_type_id, constr_id, brand_id, model_id, category_id, instr_type_note)
    VALUES
        (      0,  0,  0,   0,  0, NULL            ); --   0 -- Tipologia per la stazione

    INSERT INTO equipments.frequencies
        (freq_id, freq_desc, freq_label, freq_db)
    VALUES
        (0, 'Da definire', 'N.d.', NULL);

    INSERT INTO equipments.operations
        (op_id, op_desc)
    VALUES
        (DEFAULT, 'Operazione UNO');

    INSERT INTO equipments.operations_category
        (op_ca_id, op_ca_desc)
    VALUES
        (DEFAULT, 'Categoria di operazione UNO');

-- SCHEMA reports

    INSERT INTO reports.ticket_categories VALUES (1, 'Categoria UNO', 'mdi-tag text-success' );
    INSERT INTO reports.ticket_types VALUES (1, 'Tipo UNO' );
    INSERT INTO reports.ticket_urgencies VALUES ( 1, 'Urgenza UNO', 'info' );
    INSERT INTO reports.ticket_frequencies (tf_id, tf_desc, tf_label, tf_db, tf_order) VALUES ( 0, 'Solo una volta', '1v', NULL,  0 ); -- 0


    INSERT INTO reports.ced_ticket_types
        (ctt_id, ctt_name, ctt_desc, ctt_icon, ctt_colour)
    VALUES
        ( 1, 'Flusso dati (import)'     , 'I dati non vengono acquisiti correttamente dalla periferia'         , 'fa-solid fa-arrow-progress'       , 'purple'  ),
        ( 2, 'Web service (export)'     , 'I dati non vengono trasmessi correttamente verso sistemi esterni'   , 'fa-solid fa-arrow-right-from-line', 'primary' ),
        ( 3, 'Bug software'             , 'Il software presenta un comportamento anomalo o inatteso'           , 'fa-solid fa-bug'                  , 'violet'  ),
        ( 4, 'Malfunzionamento software', 'Una funzionalità che è sempre stata operativa, ora non funziona più', 'fa-solid fa-circle-exclamation'   , 'danger'  ),
        ( 5, 'Richiesta di assistenza'  , 'Hai bisogno di supporto su una pagina o funzione del sistema'       , 'fa-solid fa-messages'             , 'info'    ),
        (99, 'Altro'                    , 'La segnalazione non rientra nelle tipologie precedenti'             , 'fa-solid fa-waves-sine'           , 'esmerald');

    -- inserts
    INSERT INTO reports.ced_ticket_urgencies VALUES ( 1, 'Bassa'    , 'malfunzionamenti del sistema che non impediscono il regolare svolgimento di un processo applicativo, ma che siano causa di disagi nell’uso per l’utente.<br>(Esempio Dataview, Grafici OpenAir, Reportistica)', 'warning' );
    INSERT INTO reports.ced_ticket_urgencies VALUES (10, 'Media'    , 'malfunzionamenti tali da non impedire il regolare svolgimento di un processo applicativo, ma che siano causa di inefficienza o di problemi operativi per l’utente.<br>(Esempio Ticketing, Anagrafica, Mapper, Validazione Multilivello)', 'primary' );
    INSERT INTO reports.ced_ticket_urgencies VALUES (20, 'Alta'     , 'malfunzionamenti che impediscono l’utilizzo corretto di una singola funzionalità, pur non impedendo totalmente lo svolgimento del processo applicativo al quale la funzionalità appartiene;<br>(Esempio Visualizer, Analyser , Export Dati, Web Service)', 'danger'  );
    INSERT INTO reports.ced_ticket_urgencies VALUES (30, 'Bloccante', 'malfunzionamenti che impediscono il regolare svolgimento di un intero processo applicativo;<br>(Esempio i moduli Portale/Autenticazione, Validazione, Statistiche, Import Dati)', 'purple'  );


    INSERT INTO reports.calibration_reasons (calib_re_id, calib_re_name) VALUES (DEFAULT, 'Motivo UNO' );
    INSERT INTO reports.calibration_methods (calib_me_id, calib_me_name) VALUES (DEFAULT, 'Metodo UNO' );

-- SCHEMA client_lig_alims

    INSERT INTO client_lig_alims.analytics VALUES (1, 'Analisi UNO');
    INSERT INTO client_lig_alims.arguments VALUES (1, 'Argomento UNO');
