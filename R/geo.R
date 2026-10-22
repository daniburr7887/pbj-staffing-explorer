# County outlines keyed the same way as agg_county_month (state + 3-digit
# county code), built from the maps package's FIPS crosswalks. Joining on
# FIPS instead of county names avoids mismatches like "St. Louis" vs
# "st louis" or "DeKalb" vs "de kalb".
#
# Coverage gaps (see docs/decisions.md):
#   - AK, HI and territories: not in the maps package.
#   - CT: CMS reports Connecticut's 9 planning regions (which replaced its
#     counties in 2022); the maps package only has the old 8 counties.
#   - Virginia independent cities: mostly missing from the maps package; the
#     app reports how many places with data aren't drawn.

county_shapes <- function() {
  outlines <- ggplot2::map_data("county")
  outlines$polyname <- paste(outlines$region, outlines$subregion, sep = ",")

  fips <- maps::county.fips
  fips$polyname <- sub(":.*$", "", fips$polyname)  # "san juan:lopez island" -> "san juan"
  fips <- fips[!duplicated(fips$polyname), ]

  states <- maps::state.fips[!duplicated(maps::state.fips$fips), c("fips", "abb")]

  out <- merge(outlines, fips, by = "polyname")
  out$state <- states$abb[match(out$fips %/% 1000, states$fips)]
  out$county_code <- sprintf("%03d", out$fips %% 1000)
  out[order(out$group, out$order), c("long", "lat", "group", "order", "subregion", "state", "county_code")]
}

STATES_WITHOUT_OUTLINES <- c(
  AK = "County outlines aren't available for Alaska.",
  HI = "County outlines aren't available for Hawaii.",
  CT = "Connecticut replaced its counties with planning regions in 2022, and outlines for the new regions aren't available.",
  PR = "County outlines aren't available for territories.",
  GU = "County outlines aren't available for territories.",
  VI = "County outlines aren't available for territories.",
  MP = "County outlines aren't available for territories.",
  AS = "County outlines aren't available for territories."
)
