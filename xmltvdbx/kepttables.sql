
set search_path = xmltv;                                                
DROP TABLE bayes_toks;                                                  
drop table prg_interest;

CREATE TABLE xmltv.prg_interest
(
  prg_title text NOT NULL,
  pint_class varchar(1024) NOT NULL,
  CONSTRAINT prg_interest_pkey PRIMARY KEY (prg_title),
  CONSTRAINT pint_cv_ref FOREIGN KEY (pint_class) REFERENCES xmltv.cv_interest (pint_class) ON UPDATE RESTRICT ON DELETE RESTRICT
) 
WITHOUT OIDS;
--ALTER TABLE xmltv.prg_interest OWNER TO wwwdata;
--GRANT ALL ON TABLE xmltv.prg_interest TO wwwdata WITH GRANT OPTION;
GRANT SELECT ON TABLE xmltv.prg_interest TO cheetah;
COMMENT ON TABLE xmltv.prg_interest IS 'programme interest classification
(by programme title)';

-- Table: xmltv.bayes_toks

CREATE TABLE xmltv.bayes_toks
(
  prg_oid int8,
  prg_title text,
  tok_src char(1) NOT NULL,
  tok_name varchar(50) NOT NULL,
  tok_subname varchar(50),
  tok_value text NOT NULL,
  pint_class varchar(1024) NOT NULL,
  CONSTRAINT "$1" FOREIGN KEY (pint_class) REFERENCES xmltv.cv_interest (pint_class) ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT ux_tok_uniq UNIQUE (tok_src, tok_name, tok_subname, tok_value, prg_oid),
  CONSTRAINT bayes_toks_tok_src CHECK (tok_src = 'p'::bpchar OR tok_src = 'c'::bpchar)
) 
WITHOUT OIDS;
--ALTER TABLE xmltv.bayes_toks OWNER TO wwwdata;
--GRANT ALL ON TABLE xmltv.bayes_toks TO wwwdata WITH GRANT OPTION;
GRANT SELECT ON TABLE xmltv.bayes_toks TO cheetah;
COMMENT ON TABLE xmltv.bayes_toks IS 'full token data for bayes learning';
COMMENT ON COLUMN xmltv.bayes_toks.tok_value IS 'token value, not att value';
