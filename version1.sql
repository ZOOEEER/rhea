create database rhea_test;

create table reaction(
    about       varchar(12),
    id          int, /* 9位数(dec) */
    accession   varchar(14),
    label       varchar(3000),
    html_pres   varchar(3000),
    is_CB       char(1),
    is_trans    char(1),
    status      varchar(14),
    primary key (id)
);

LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/reaction.tsv' INTO TABLE reaction
    LINES TERMINATED BY '\r\n';

create table compound(
    about           varchar(28),
    compound_id     int,
    accession       varchar(16),
    label           varchar(3000),
    html_pres       varchar(3000),
    formula         varchar(100),
    charge          varchar(30), /*为啥这个这么大，不科学...*/
    molecular_type  varchar(30),
    id              int AUTO_INCREMENT,
    primary key (id)
);
LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/compound.tsv' INTO TABLE compound
    LINES TERMINATED BY '\r\n';
SELECT * FROM compound LIMIT 100;

create table enzyme(
    about       varchar(16),
    ec          varchar(12),
    label       varchar(300),
    is_obsolete char(1),
    primary key (about)
);
LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/enzyme.tsv' INTO TABLE enzyme
    LINES TERMINATED BY '\r\n';
SELECT * FROM enzyme LIMIT 100;

start transaction;
create table reactionParticipants_compound(
    container   varchar(40),
    content     varchar(28),
    location    char(1),
    id          int AUTO_INCREMENT,
    primary key (id)
);
LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/reactionParticipants_compound.tsv' INTO TABLE reactionParticipants_compound
    LINES TERMINATED BY '\r\n';
SELECT * FROM reactionParticipants_compound LIMIT 100;
commit;

start transaction;
create table catalysisParticipants_enzyme(
    container   varchar(46),
    content     varchar(32),
    id          int AUTO_INCREMENT,
    primary key (id)
);
LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/catalysisParticipants_enzyme.tsv' INTO TABLE catalysisParticipants_enzyme
    LINES TERMINATED BY '\r\n';
SELECT * FROM catalysisParticipants_enzyme LIMIT 100;
commit;

drop table enzyme_enzyme;
start transaction;
create table enzyme_enzyme(
    outset      varchar(40),
    relation    varchar(32),
    destin      varchar(40),
    id          int AUTO_INCREMENT,
    primary key (id)
);
LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/enzyme_enzyme.tsv' INTO TABLE enzyme_enzyme
    LINES TERMINATED BY '\r\n';
SELECT * FROM enzyme_enzyme LIMIT 100;
commit;


-- 1. 基本的搜索任务,以反应条目出发，关联到与之相关的酶和化学物质
-- '10524' as an example
select id, label
    from reaction
    where id = '10524';
-- 从反应出发得到催化其反应的酶
-- ec号
select container, content
    from catalysisParticipants_enzyme
    where container like '%10524%';
-- 详情 ec, label
select ec, label
    from enzyme
    where about in (select content
                        from catalysisParticipants_enzyme
                        where container like '%10524%');

-- 从反应出发得到该反应的底物和产物（暂时还不能做出底物和产物的区分...）
-- compound
select container, content
    from reactionParticipants_compound
    where container like "%10524%";
-- 详情 label, formula, molecular_type
select about, label, formula, molecular_type 
    from compound
    where about in (select content
                        from reactionParticipants_compound
                        where container like '%10524%');
/*---------------------------------------------
-- 从反应物出发找酶
-- 以香叶醇 gereniol 为例：
---------------------------------------------*/
-- (1) 化合物
select *
    from compound
    where label like '%Geraniol%';
-- rh:Compound_4386
-- create view candReaction
-- (2) 关联反应
select container, substring(container, 16, 5) as reaction_id
    from reactionParticipants_compound
    where content = 'rh:Compound_4386';
/*
    rh:Participant_14521_compound_4386
    rh:Participant_30715_compound_4386
    rh:Participant_32495_compound_4386
    rh:Participant_32679_compound_4386
    rh:Participant_34347_compound_4386
    rh:Participant_54656_compound_4386
    rh:Participant_61660_compound_4386
*/
-- 定义一个临时视图
drop view temp;
create view temp
as
select id
    from reaction
    where id in (select substring(container, 16, 5) as reaction_id
                    from reactionParticipants_compound
                    where content = 'rh:Compound_4386');
-- (3) 酶
select ec, label
    from enzyme
    where about in (select content
                        from catalysisParticipants_enzyme
                        where container like '%10524%');
select ec, label
    from enzyme
    where about in (select content
                        from catalysisParticipants_enzyme
                        where substring(container, 16, 5) in (select cast(id as char) from temp)
    );
-- total 
select ec, label
    from enzyme
    where about in (select content
                        from catalysisParticipants_enzyme
                        where substring(container, 16, 5) in (select cast(id as char) 
                                                                from (select id
                                                                        from reaction
                                                                        where id in (select substring(container, 16, 5) as reaction_id
                                                                                        from reactionParticipants_compound
                                                                                        where content = 'rh:Compound_4386')
                                                                        ) as temp2
                                                                )
                        );
/*
1.1.1.183	Geraniol dehydrogenase (NADP(+))
1.1.1.347	Geraniol dehydrogenase (NAD(+))
1.14.14.83	Geraniol 8-hydroxylase
2.7.1.216	Farnesol kinase
3.1.7.11	Geranyl diphosphate diphosphatase
5.4.4.4	Geraniol isomerase
5.4.4.8	Linalool isomerase
*/

-- 从酶到反应也是类似的。。。
-- 1.1.1.183	Geraniol dehydrogenase (NADP(+))
-- (1) 酶到反应 假设模糊匹配了一堆酶的反应...
select container, content, substring(container,16,5) as rid
    from catalysisParticipants_enzyme
    where content like '%3.1.1.3%';

drop view temp;
create view temp
as
select distinct substring(container,16,5) as rid
    from catalysisParticipants_enzyme
    where content like '%3.1.1.3';
select *
    from reaction
    where id in (select substring(container,16,5)
                    from catalysisParticipants_enzyme
                    where content like '%3.1.1.3%');

-- (2) 酶到物质
select *  /*39个*/
    from reactionParticipants_compound
    where substring(container,16,5) in (select rid from temp);
select accession, label
    from compound
    where about in (select content  /*39个*/
                        from reactionParticipants_compound
                        where substring(container,16,5) in (select rid from temp));
-- total 一下跑不完。。。
/*
select accession, label
    from compound
    where about in (select content  
                        from reactionParticipants_compound
                        where substring(container,16,5) in (select rid from 
                        (select substring(container,16,5) as rid
                                from catalysisParticipants_enzyme
                                where content like '%3.1.1.3') as temp ) );
*/


/*---------------------------------------------
-- 2. 酶的ec分类系统（一个简单本体的例子）
---------------------------------------------*/

/*
    skos:broaderTransitive

*/
-- 与 ec:3.1.1.3有关的关系
select *
    from enzyme_enzyme
    where outset = 'ec:3.1.1.3' or destin = 'ec:3.1.1.3';
-- ec:3.1.1.-的 'skos:narrowerTransitive'
select e.about as about, label
    from enzyme_enzyme as ee inner join enzyme as e
      on  ee.destin = e.about
    where ee.outset = 'ec:3.1.1.-' and ee.relation = 'skos:narrowerTransitive';

select e.about as about, label, is_obsolete
    from enzyme_enzyme as ee inner join enzyme as e
      on  ee.destin = e.about
    where ee.outset in (select destin
                            from enzyme_enzyme
                            where outset = 'ec:3.1.1.-' and relation = 'skos:broaderTransitive' )
        and ee.relation = 'skos:narrowerTransitive';

-- drop table compounds;
-- drop table relation;

/*
select count(*) 
    from (select distinct content
            from catalysisParticipants_enzyme) as c1;
*/
/*
SELECT * 
    FROM reactionParticipants_compound
    where location <> '0';
*/


/*
SELECT * FROM `rhea_test`.`reaction` LIMIT 10;
Drop table reactionSide;
create table reactionSide(
    about               varchar(14),
    reaction_id         int,
    reaction_side       char(1),
    transformable_to    varchar(14),
    curated_order       char(1),
    primary key (reaction_id, reaction_side)
);

LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/reactionSide.tsv' INTO TABLE reactionSide
    LINES TERMINATED BY '\r\n';

SELECT * FROM reactionSide LIMIT 10;

drop table reactionSide_reactionParticipants;
create table reactionSide_reactionParticipants(
    container   varchar(14),
    coeffient   varchar(7),
    content     varchar(50),
    id          int AUTO_INCREMENT,
    primary key (id)
);

LOAD DATA LOCAL INFILE 'D:/Desktop/SQL/db/reactionSide_reactionParticipants.tsv' INTO TABLE reactionSide_reactionParticipants
    LINES TERMINATED BY '\r\n';

SELECT * FROM reactionSide_reactionParticipants LIMIT 10;
*/


