<?xml version="1.0" encoding="UTF-8"?>
<!--
    Copyright 2012-2021 Barista Software
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:k="http://www.ehealth.fgov.be/standards/kmehr/schema/v1" xmlns="http://www.ehealth.fgov.be/standards/kmehr/schema/v1"
		exclude-result-prefixes="k">
	<xsl:output method="xml" encoding="utf-8" indent="yes"/>
	<xsl:strip-space elements="*"/>

	<xsl:param name="lang" select="'nl'"/>

	<xsl:variable name="deprecatedPeriodicities" select="';U;UA;UD;UE;UH;UN;UQ;US;UT;UV;UW;UX;UZ;ondemand;'"/>
	<xsl:variable name="i18n" select="document('complex-regimen-i18n.xml')/i18n"/>

	<xsl:template match="node()|@*">
		<xsl:copy>
			<xsl:apply-templates select="node()|@*"/>
		</xsl:copy>
	</xsl:template>

	<xsl:template match="k:posology">
		<xsl:choose>
			<!-- If a periodicity is used in combination with a posology, it should be removed and a corresponding piece of text should be added the posology. -->
			<xsl:when test="../k:frequency/k:periodicity">
				<posology>
					<text>
						<xsl:attribute name="L">
							<xsl:value-of select="k:text[1]/@L"/>
						</xsl:attribute>

						<!-- Add the "*converted*" prefix. -->
						<xsl:value-of select="$i18n/converted[lang($lang)]"/>
						<xsl:text> </xsl:text>

						<!-- Add the text. -->
						<xsl:value-of select="k:text"/>

						<!-- Add the periodicity. -->
						<xsl:for-each select="../k:frequency/k:periodicity[1]">
							<xsl:value-of select="'&#10;'"/>
							<xsl:apply-templates select="." mode="text">
								<!-- Use the language of the original posology. -->
								<xsl:with-param name="lang">
									<xsl:choose>
										<xsl:when test="contains(';en;fr;nl;', concat(';', ../../k:posology/k:text/@L, ';'))"><xsl:value-of select="../../k:posology/k:text/@L"/></xsl:when>
										<xsl:otherwise><xsl:value-of select="$lang"/></xsl:otherwise>
									</xsl:choose>
								</xsl:with-param>
							</xsl:apply-templates>
						</xsl:for-each>
					</text>
				</posology>
			</xsl:when>
			<!-- Otherwise just keep the posology as is. -->
			<xsl:otherwise>
				<xsl:copy>
					<xsl:apply-templates select="node()|@*"/>
				</xsl:copy>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="k:regimen">
		<xsl:choose>
			<!--
				If the regimen is complex, replace it with a free-text posology.
				A regimen is considered complex when either:
				- a specific date is used.
				- no daynumber is specified, or the daynumber is not 1.
				- a weekday is used.
				- no daytime is specified.
				- a deprecated periodicity is used.
			-->
			<xsl:when test="k:date or not(k:daynumber) or  k:daynumber[. != 1] or k:weekday or not(k:daytime) or ../k:frequency/k:periodicity[contains($deprecatedPeriodicities, concat(';', k:cd[@S='CD-PERIODICITY'], ';'))]">
				<xsl:apply-templates select="." mode="text"/>
			</xsl:when>
			<!-- Otherwise just keep the simple regimen. -->
			<xsl:otherwise>
				<xsl:copy>
					<xsl:apply-templates select="node()|@*"/>
				</xsl:copy>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="k:regimen" mode="text">
		<posology>
			<text>
				<xsl:attribute name="L">
					<xsl:value-of select="$lang"/>
				</xsl:attribute>

				<!-- Add the "*converted*" prefix. -->
				<xsl:value-of select="$i18n/converted[lang($lang)]"/>
				<xsl:text> </xsl:text>

				<xsl:for-each select="k:quantity">
					<xsl:variable name="index" select="count(preceding-sibling::k:quantity)"/>

					<!-- Add a newline. -->
					<xsl:if test="$index > 0">
						<xsl:value-of select="'&#10;'"/>
					</xsl:if>

					<!-- Convert the daynumber/date/weekday between this quantity and the previous quantity to text. -->
					<xsl:for-each select="preceding-sibling::k:daynumber[count(preceding-sibling::k:quantity) = $index][1]">
						<xsl:apply-templates select="." mode="text"/>
						<xsl:text>: </xsl:text>
					</xsl:for-each>
					<xsl:for-each select="preceding-sibling::k:date[count(preceding-sibling::k:quantity) = $index][1]">
						<xsl:apply-templates select="." mode="text"/>
						<xsl:text>: </xsl:text>
					</xsl:for-each>
					<xsl:for-each select="preceding-sibling::k:weekday[count(preceding-sibling::k:quantity) = $index][1]">
						<xsl:apply-templates select="." mode="text"/>
						<xsl:text>: </xsl:text>
					</xsl:for-each>

					<!-- Convent this quantity and unit to text. -->
					<xsl:apply-templates select="." mode="text"/>

					<!-- Convert the daytime between this quantity and the previous quantity to text. -->
					<xsl:for-each select="preceding-sibling::k:daytime[count(preceding-sibling::k:quantity) = $index][1]">
						<xsl:text> (</xsl:text>
						<xsl:apply-templates select="." mode="text"/>
						<xsl:text>)</xsl:text>
					</xsl:for-each>
				</xsl:for-each>

				<!-- Append the periodicity. -->
				<xsl:for-each select="../k:frequency/k:periodicity[1]">
					<xsl:value-of select="'&#10;'"/>
					<xsl:apply-templates select="." mode="text"/>
				</xsl:for-each>
			</text>
		</posology>
	</xsl:template>

	<xsl:template match="k:frequency">
		<!--
			Omit the frequency when used in combination with a posology, or when it contains a deprecated periodicity value.
			This means that the frequency should be omitted whenever the output contains a posology. This will happen when the input contains either:
				- a posology
				- a complex regimen
				- a deprecated periodicity
			The omitted periodicity value should be included in the free-text posology instead.
		-->
		<xsl:if test="not(../k:posology
				or ../k:regimen[k:date or not(k:daynumber) or k:daynumber[. != 1] or k:weekday or not(k:daytime)]
				or k:periodicity[contains($deprecatedPeriodicities, concat(';', k:cd[@S='CD-PERIODICITY'], ';'))])">
			<xsl:copy>
				<xsl:apply-templates select="node()|@*"/>
			</xsl:copy>
		</xsl:if>
	</xsl:template>

	<xsl:template match="k:daynumber" mode="text">
        <xsl:value-of select="$i18n/day[lang($lang)]"/>
		<xsl:text> </xsl:text>
		<xsl:value-of select="."/>
	</xsl:template>

	<xsl:template match="k:date" mode="text">
		<xsl:value-of select="substring(., 9, 2)"/>
		<xsl:text>-</xsl:text>
		<xsl:value-of select="substring(. ,6 ,2)"/>
		<xsl:text>-</xsl:text>
		<xsl:value-of select="substring(., 1, 4)"/>
	</xsl:template>

	<xsl:template match="k:weekday" mode="text">
		<xsl:variable name="code" select="k:cd[@S='CD-WEEKDAY']"/>
		<xsl:value-of select="$i18n/weekday[@code=$code and lang($lang)]"/>
	</xsl:template>

	<xsl:template match="k:daytime" mode="text">
		<xsl:apply-templates select="k:time" mode="text"/>
		<xsl:apply-templates select="k:dayperiod" mode="text"/>
	</xsl:template>

	<xsl:template match="k:time" mode="text">
		<xsl:value-of select="$i18n/atTime[lang($lang)]"/>
		<xsl:text> </xsl:text>
		<xsl:value-of select="."/>
	</xsl:template>

	<xsl:template match="k:dayperiod" mode="text">
		<xsl:variable name="code" select="k:cd[@S='CD-DAYPERIOD']"/>
		<xsl:value-of select="$i18n/dayperiod[@code=$code and lang($lang)]"/>
	</xsl:template>

	<xsl:template match="k:quantity" mode="text">
		<xsl:value-of select="k:decimal"/>
		<xsl:text> </xsl:text>
		<xsl:apply-templates select="k:unit" mode="text"/>
	</xsl:template>

	<xsl:template match="k:unit[k:cd[@S='CD-ADMINISTRATIONUNIT']]" mode="text">
		<xsl:variable name="code" select="k:cd[@S='CD-ADMINISTRATIONUNIT']"/>
		<xsl:value-of select="$i18n/administrationunit[@code=$code and lang($lang)]"/>
	</xsl:template>

	<xsl:template match="k:periodicity" mode="text">
		<xsl:param name="lang" select="$lang"/>
		<xsl:variable name="code" select="k:cd[@S='CD-PERIODICITY']"/>
		<xsl:value-of select="$i18n/periodicity[@code=$code and lang($lang)]"/>
	</xsl:template>
</xsl:stylesheet>
