import { logger } from '../utils/logger';
import { ChallengeResponse, AntiProxyFlags, AttendanceAnalytics } from '../types/attendance';
import { redisClient } from '../config/redis';
import moment from 'moment';

interface ProximityData {
  rssi: number;
  distance: number;
  signalStrength: 'weak' | 'medium' | 'strong';
}

interface LocationData {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
}

interface WiFiData {
  networks: string[];
  count: number;
  suspiciousNetworks: string[];
}

interface DevicePattern {
  deviceId: string;
  userId: string;
  patterns: {
    responseTimes: number[];
    locations: LocationData[];
    rssiValues: number[];
    wifiNetworks: string[][];
  };
  riskScore: number;
}

export class AntiProxyService {
  private static readonly RSSI_THRESHOLDS = {
    VERY_WEAK: -90,
    WEAK: -70,
    MEDIUM: -50,
    STRONG: -30
  };

  private static readonly RESPONSE_TIME_LIMITS = {
    MIN_HUMAN_RESPONSE: 500, // 500ms minimum human response time
    MAX_REASONABLE_RESPONSE: 10000, // 10s maximum reasonable response time
    SUSPICIOUS_FAST: 200 // Under 200ms is likely automated
  };

  private static readonly LOCATION_THRESHOLDS = {
    MAX_ACCURACY_ERROR: 50, // 50m accuracy threshold
    MIN_MOVEMENT_TIME: 30000, // 30s minimum time between significant location changes
    SUSPICIOUS_JUMP_DISTANCE: 1000 // 1km suspicious movement distance
  };

  private static readonly WIFI_PATTERNS = {
    MIN_EXPECTED_NETWORKS: 1,
    MAX_REASONABLE_NETWORKS: 20,
    SUSPICIOUS_NETWORKS: [
      'MOCK_WIFI', 'TEST_AP', 'FAKE_NETWORK', 'EMULATOR_WIFI',
      'SIMULATOR_AP', 'DEBUG_WIFI', 'PROXY_NETWORK'
    ]
  };

  /**
   * Comprehensive anti-proxy analysis
   */
  async analyzeResponse(response: ChallengeResponse): Promise<AntiProxyFlags> {
    try {
      logger.info(`Analyzing response for student: ${response.studentId}`);
      
      const flags: Partial<AntiProxyFlags> = {};
      const analysisDetails: any = {};

      // 1. RSSI Analysis
      const proximityAnalysis = this.analyzeProximity(response.rssi);
      if (proximityAnalysis.signalStrength === 'weak') {
        flags.weakSignal = true;
        analysisDetails.proximity = proximityAnalysis;
      }

      // 2. Response Timing Analysis
      const timingAnalysis = this.analyzeResponseTiming(response);
      if (timingAnalysis.suspicious) {
        flags.lateResponse = timingAnalysis.tooSlow;
        flags.unusualPattern = timingAnalysis.tooFast;
        analysisDetails.timing = timingAnalysis;
      }

      // 3. Location Analysis
      if (response.location) {
        const locationAnalysis = await this.analyzeLocation(response.location, response.studentId);
        flags.invalidLocation = locationAnalysis.invalid;
        flags.mockedLocation = locationAnalysis.mocked;
        if (locationAnalysis.invalid || locationAnalysis.mocked) {
          analysisDetails.location = locationAnalysis;
        }
      }

      // 4. WiFi Environment Analysis
      if (response.wifiNetworks && response.wifiNetworks.length > 0) {
        const wifiAnalysis = this.analyzeWiFiEnvironment(response.wifiNetworks);
        flags.suspiciousWifi = wifiAnalysis.suspicious;
        if (wifiAnalysis.suspicious) {
          analysisDetails.wifi = wifiAnalysis;
        }
      }

      // 5. Device Pattern Analysis
      const deviceAnalysis = await this.analyzeDevicePattern(response);
      flags.duplicateDevice = deviceAnalysis.duplicateDetected;
      flags.rootedDevice = deviceAnalysis.rootedDetected;
      if (deviceAnalysis.duplicateDetected || deviceAnalysis.rootedDetected) {
        analysisDetails.device = deviceAnalysis;
      }

      // 6. Behavioral Pattern Analysis
      const behaviorAnalysis = await this.analyzeBehavioralPattern(response);
      flags.unusualPattern = behaviorAnalysis.unusual;
      if (behaviorAnalysis.unusual) {
        analysisDetails.behavior = behaviorAnalysis;
      }

      // Calculate overall risk score
      const riskScore = this.calculateRiskScore(flags);
      analysisDetails.riskScore = riskScore;

      // Store analysis for future pattern detection
      await this.storeAnalysisData(response, flags, analysisDetails);

      logger.info(`Anti-proxy analysis complete for ${response.studentId}. Risk score: ${riskScore}`);

      return {
        weakSignal: flags.weakSignal || false,
        duplicateDevice: flags.duplicateDevice || false,
        invalidLocation: flags.invalidLocation || false,
        suspiciousWifi: flags.suspiciousWifi || false,
        lateResponse: flags.lateResponse || false,
        invalidChallenge: flags.invalidChallenge || false,
        rootedDevice: flags.rootedDevice || false,
        mockedLocation: flags.mockedLocation || false,
        unusualPattern: flags.unusualPattern || false,
        details: analysisDetails
      };

    } catch (error) {
      logger.error(`Error in anti-proxy analysis for ${response.studentId}:`, error);
      throw error;
    }
  }

  /**
   * Analyze Bluetooth signal strength and proximity
   */
  private analyzeProximity(rssi: number): ProximityData {
    let signalStrength: 'weak' | 'medium' | 'strong';
    
    if (rssi <= AntiProxyService.RSSI_THRESHOLDS.WEAK) {
      signalStrength = 'weak';
    } else if (rssi <= AntiProxyService.RSSI_THRESHOLDS.MEDIUM) {
      signalStrength = 'medium';
    } else {
      signalStrength = 'strong';
    }

    // Rough distance calculation (this is approximate)
    const distance = Math.pow(10, (-69 - rssi) / 20);

    return {
      rssi,
      distance,
      signalStrength
    };
  }

  /**
   * Analyze response timing patterns
   */
  private analyzeResponseTiming(response: ChallengeResponse): any {
    const responseTime = Date.now() - new Date(response.respondedAt).getTime();
    
    return {
      responseTime,
      tooFast: responseTime < AntiProxyService.RESPONSE_TIME_LIMITS.SUSPICIOUS_FAST,
      tooSlow: responseTime > AntiProxyService.RESPONSE_TIME_LIMITS.MAX_REASONABLE_RESPONSE,
      suspicious: responseTime < AntiProxyService.RESPONSE_TIME_LIMITS.MIN_HUMAN_RESPONSE ||
                 responseTime > AntiProxyService.RESPONSE_TIME_LIMITS.MAX_REASONABLE_RESPONSE
    };
  }

  /**
   * Analyze GPS location for authenticity
   */
  private async analyzeLocation(location: any, studentId: string): Promise<any> {
    const analysis = {
      invalid: false,
      mocked: false,
      details: {} as any
    };

    // Check for obviously fake coordinates
    if (location.latitude === 0 && location.longitude === 0) {
      analysis.invalid = true;
      analysis.details.reason = 'Zero coordinates';
    }

    // Check for unrealistic accuracy
    if (location.accuracy && location.accuracy < 1) {
      analysis.mocked = true;
      analysis.details.suspiciousAccuracy = location.accuracy;
    }

    // Check location movement patterns
    const lastLocation = await this.getLastKnownLocation(studentId);
    if (lastLocation) {
      const distance = this.calculateDistance(lastLocation, location);
      const timeDiff = location.timestamp - lastLocation.timestamp;
      
      if (distance > AntiProxyService.LOCATION_THRESHOLDS.SUSPICIOUS_JUMP_DISTANCE &&
          timeDiff < AntiProxyService.LOCATION_THRESHOLDS.MIN_MOVEMENT_TIME) {
        analysis.invalid = true;
        analysis.details.suspiciousMovement = { distance, timeDiff };
      }
    }

    // Store current location for future analysis
    await this.storeLocation(studentId, location);

    return analysis;
  }

  /**
   * Analyze WiFi environment for proxy detection
   */
  private analyzeWiFiEnvironment(networks: string[]): any {
    const analysis = {
      suspicious: false,
      networkCount: networks.length,
      suspiciousNetworks: [] as string[],
      details: {} as any
    };

    // Check network count
    if (networks.length < AntiProxyService.WIFI_PATTERNS.MIN_EXPECTED_NETWORKS ||
        networks.length > AntiProxyService.WIFI_PATTERNS.MAX_REASONABLE_NETWORKS) {
      analysis.suspicious = true;
      analysis.details.unusualNetworkCount = networks.length;
    }

    // Check for suspicious network names
    for (const network of networks) {
      for (const suspicious of AntiProxyService.WIFI_PATTERNS.SUSPICIOUS_NETWORKS) {
        if (network.toUpperCase().includes(suspicious)) {
          analysis.suspicious = true;
          analysis.suspiciousNetworks.push(network);
        }
      }
    }

    return analysis;
  }

  /**
   * Analyze device patterns for duplicates and tampering
   */
  private async analyzeDevicePattern(response: ChallengeResponse): Promise<any> {
    const analysis = {
      duplicateDetected: false,
      rootedDetected: false,
      details: {} as any
    };

    // Check for duplicate device usage
    const deviceUsage = await this.getDeviceUsagePattern(response.deviceContext.deviceId);
    if (deviceUsage && deviceUsage.userIds.length > 1) {
      analysis.duplicateDetected = true;
      analysis.details.multipleUsers = deviceUsage.userIds;
    }

    // Check for rooted/jailbroken device indicators
    if (response.deviceContext.securityFlags) {
      const flags = response.deviceContext.securityFlags;
      if (flags.includes('rooted') || flags.includes('jailbroken') || flags.includes('emulator')) {
        analysis.rootedDetected = true;
        analysis.details.securityFlags = flags;
      }
    }

    return analysis;
  }

  /**
   * Analyze behavioral patterns
   */
  private async analyzeBehavioralPattern(response: ChallengeResponse): Promise<any> {
    const pattern = await this.getUserBehaviorPattern(response.studentId);
    
    if (!pattern) {
      return { unusual: false };
    }

    const analysis = {
      unusual: false,
      details: {} as any
    };

    // Analyze response time patterns
    const avgResponseTime = pattern.responseTime.average;
    const currentResponseTime = Date.now() - new Date(response.respondedAt).getTime();
    
    if (Math.abs(currentResponseTime - avgResponseTime) > (avgResponseTime * 0.5)) {
      analysis.unusual = true;
      analysis.details.responseTimeDeviation = {
        current: currentResponseTime,
        average: avgResponseTime,
        deviation: Math.abs(currentResponseTime - avgResponseTime)
      };
    }

    return analysis;
  }

  /**
   * Calculate overall risk score
   */
  private calculateRiskScore(flags: Partial<AntiProxyFlags>): number {
    const weights = {
      weakSignal: 0.2,
      duplicateDevice: 0.3,
      invalidLocation: 0.25,
      suspiciousWifi: 0.15,
      lateResponse: 0.1,
      invalidChallenge: 0.4,
      rootedDevice: 0.35,
      mockedLocation: 0.3,
      unusualPattern: 0.2
    };

    let totalScore = 0;
    let totalWeight = 0;

    for (const [flag, weight] of Object.entries(weights)) {
      if (flags[flag as keyof AntiProxyFlags]) {
        totalScore += weight;
      }
      totalWeight += weight;
    }

    return Math.min(totalScore / totalWeight * 100, 100);
  }

  /**
   * Store analysis data for pattern learning
   */
  private async storeAnalysisData(
    response: ChallengeResponse,
    flags: Partial<AntiProxyFlags>,
    details: any
  ): Promise<void> {
    const analysisData = {
      studentId: response.studentId,
      sessionId: response.sessionId,
      timestamp: Date.now(),
      flags,
      details,
      response: {
        rssi: response.rssi,
        responseTime: Date.now() - new Date(response.respondedAt).getTime(),
        location: response.location,
        wifiNetworks: response.wifiNetworks
      }
    };

    const key = `analysis:${response.studentId}:${Date.now()}`;
    await redisClient.setex(key, 86400 * 7, JSON.stringify(analysisData)); // Store for 7 days
  }

  /**
   * Helper methods for data retrieval and storage
   */
  private async getLastKnownLocation(studentId: string): Promise<LocationData | null> {
    const key = `location:${studentId}:last`;
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  }

  private async storeLocation(studentId: string, location: LocationData): Promise<void> {
    const key = `location:${studentId}:last`;
    await redisClient.setex(key, 3600, JSON.stringify(location)); // Store for 1 hour
  }

  private calculateDistance(loc1: LocationData, loc2: LocationData): number {
    const R = 6371e3; // Earth's radius in meters
    const φ1 = loc1.latitude * Math.PI / 180;
    const φ2 = loc2.latitude * Math.PI / 180;
    const Δφ = (loc2.latitude - loc1.latitude) * Math.PI / 180;
    const Δλ = (loc2.longitude - loc1.longitude) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  private async getDeviceUsagePattern(deviceId: string): Promise<any> {
    const key = `device:${deviceId}:usage`;
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  }

  private async getUserBehaviorPattern(studentId: string): Promise<any> {
    const key = `behavior:${studentId}:pattern`;
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  }

  /**
   * Generate anti-proxy report for session
   */
  async generateSessionReport(sessionId: string): Promise<any> {
    const analyses = await this.getSessionAnalyses(sessionId);
    
    const report = {
      sessionId,
      totalResponses: analyses.length,
      flaggedResponses: analyses.filter((a: any) => this.hasSuspiciousFlags(a.flags)).length,
      riskDistribution: {
        low: 0,
        medium: 0,
        high: 0
      },
      flagTypes: {} as any,
      recommendations: [] as string[]
    };

    // Analyze risk distribution
    for (const analysis of analyses) {
      const risk = analysis.details.riskScore || 0;
      if (risk < 30) report.riskDistribution.low++;
      else if (risk < 70) report.riskDistribution.medium++;
      else report.riskDistribution.high++;
    }

    // Count flag types
    for (const analysis of analyses) {
      for (const [flag, value] of Object.entries(analysis.flags)) {
        if (value) {
          report.flagTypes[flag] = (report.flagTypes[flag] || 0) + 1;
        }
      }
    }

    // Generate recommendations
    if (report.flaggedResponses / report.totalResponses > 0.1) {
      report.recommendations.push('High suspicious activity detected. Review attendance policies.');
    }
    if (report.flagTypes.duplicateDevice > 0) {
      report.recommendations.push('Multiple users detected on same device. Enforce device binding.');
    }
    if (report.flagTypes.weakSignal > 5) {
      report.recommendations.push('Many weak signals detected. Check classroom BLE range.');
    }

    return report;
  }

  private async getSessionAnalyses(sessionId: string): Promise<any[]> {
    const pattern = `analysis:*:*`;
    const keys = await redisClient.keys(pattern);
    const analyses = [];

    for (const key of keys) {
      const data = await redisClient.get(key);
      if (data) {
        const analysis = JSON.parse(data);
        if (analysis.sessionId === sessionId) {
          analyses.push(analysis);
        }
      }
    }

    return analyses;
  }

  private hasSuspiciousFlags(flags: Partial<AntiProxyFlags>): boolean {
    return Object.values(flags).some(flag => flag === true);
  }
}